// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
// import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

// import socket from "./socket"

import Elm from "./elm-main";

// From index.html in https://github.com/evancz/elm-todomvc

var storedState = localStorage.getItem('elm-todo-save');
var startingState = storedState ? JSON.parse(storedState) : null;
var todomvc = Elm.Todo.fullscreen(startingState);
todomvc.ports.setStorage.subscribe(function(state) {
    localStorage.setItem('elm-todo-save', JSON.stringify(state));
});
