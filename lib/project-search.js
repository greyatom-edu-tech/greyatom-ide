'use babel';

import { CompositeDisposable } from 'atom';
import SelectList from 'atom-select-list';
import path from 'path'
import _ from 'lodash'
import fuzzaldrin from 'fuzzaldrin'
import fuzzaldrinPlus from 'fuzzaldrin-plus'
import _token from './token'
import localStorage from './local-storage'
import fetch from './fetch'

function highlight (path, matches, offsetIndex) {
  let lastIndex = 0
  let matchedChars = []
  const fragment = document.createDocumentFragment()
  for (let matchIndex of matches) {
    matchIndex -= offsetIndex
    // If marking up the basename, omit path matches
    if (matchIndex < 0) {
      continue
    }
    const unmatched = path.substring(lastIndex, matchIndex)
    if (unmatched) {
      if (matchedChars.length > 0) {
        const span = document.createElement('span')
        span.classList.add('character-match')
        span.textContent = matchedChars.join('')
        fragment.appendChild(span)
        matchedChars = []
      }

      fragment.appendChild(document.createTextNode(unmatched))
    }

    matchedChars.push(path[matchIndex])
    lastIndex = matchIndex + 1
  }

  if (matchedChars.length > 0) {
    const span = document.createElement('span')
    span.classList.add('character-match')
    span.textContent = matchedChars.join('')
    fragment.appendChild(span)
  }

  // Remaining characters are plain text
  fragment.appendChild(document.createTextNode(path.substring(lastIndex)))
  return fragment
}

export default class RemoteFileSearchView {

  constructor(serializedState) {
    this.selectList = new SelectList({
      items: [],
      emptyMessage: "Fetching...",
      maxResults: 10,
      filterKeyForItem: item => item.name,
      elementForItem: (item) => {
        const filePath = item.name.replace(atom.project.remoteftp.root.path, '');
        const filterQuery = this.selectList.getFilterQuery();
        const li = document.createElement('li');
        li.classList.add('two-lines');
        const matches = fuzzaldrinPlus.match(filePath, filterQuery)

        const fileBasename = path.basename(filePath);
        const baseOffset = filePath.length - fileBasename.length;
        const primaryLine = document.createElement('div');
        primaryLine.classList.add('primary-line', 'file', 'icon', 'icon-file-text');
        primaryLine.dataset.name = fileBasename;
        primaryLine.dataset.path = filePath;
        primaryLine.appendChild(highlight(fileBasename, matches, baseOffset));
        li.appendChild(primaryLine);

        // const secondaryLine = document.createElement('div');
        // secondaryLine.classList.add('secondary-line', 'path', 'no-icon');
        // secondaryLine.appendChild(highlight(filePath, matches, 0))
        // li.appendChild(secondaryLine);
        return li;
      },
      didCancelSelection: () => { 
        this.modalPanel.hide();
      },
      didConfirmSelection: (item) => {
        localStorage.set('commit-live:last-opened-project', JSON.stringify(item));
        atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live:connect-to-project')
        this.modalPanel.hide();
      },
    });
    this.selectList.element.classList.add('remote-file-search');

    this.modalPanel = atom.workspace.addModalPanel({
      item: this.getElement(),
      visible: false
    });

    // Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    this.subscriptions = new CompositeDisposable();

    // Register command that toggles this view
    this.subscriptions.add(atom.commands.add('atom-workspace', {
      'commit-live:project-search': () => {
        if (atom.project.remoteftp && atom.project.remoteftp.isConnected()) {
          this.toggle()
        }
      }
    }));
  }

  // Returns an object that can be retrieved when package is activated
  serialize() {}

  // Tear down any state and detach
  destroy() {
    this.modalPanel.destroy();
    this.subscriptions.dispose();
    this.selectList.destroy();
  }

  getElement() {
    return this.selectList.element;
  }

  updateList(items, emptyMessage) {
    this.selectList.update({
      items,
      emptyMessage,
    });
  }

  sortByOrder(arrayOfObjects) {
    return _.sortBy(arrayOfObjects, ['order'])
  }

  retreiveProjectsFromCourse(course) {
    const listOfProjects = []
    this.sortByOrder(course.modules).forEach(
      module => this.sortByOrder(module.sections).forEach(
        section => this.sortByOrder(section.submodules).forEach(
          (submodule) => {
            if (submodule.isProject == 1) {
              listOfProjects.push({
                ...submodule,
                moduleName: module.name
              })
            }
          }
        )
      )
    )
    return listOfProjects;
  }

  fetchFileList() {
    const token = _token.get()
    this.updateList([], 'Fetching...');
    const headers = new Headers({
      Authorization: token,
    });
    const courseId = JSON.parse(localStorage.get('commit-live:user-info')).courseId;
    const apiEndpoint = atom.config.get('greyatom-ide').apiEndpoint
    const getAllProjectApi = `${apiEndpoint}/user/course/${courseId}/program`;
    fetch(getAllProjectApi, {
      headers,
    }).then((response) => {
      if (response.data) {
        const listOfProjects = this.retreiveProjectsFromCourse(response.data)
        this.updateList(listOfProjects, '');
      } else {
        this.updateList([], 'No Projects Found!');
      }
    }).catch((err) => {
      this.updateList([], 'No Projects Found!');
      console.error('Failed to fetch projects', err)
    });
  }

  toggle() {
    if (this.modalPanel.isVisible()) {
      this.modalPanel.hide();
    } else {
      this.fetchFileList();
      this.modalPanel.show();
      this.selectList.focus();
    }
  }

}
