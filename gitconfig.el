;;; gitconfig.el ---
;;
;; Filename: gitconfig.el
;; Description:
;; Author: Samuel Tonini
;; Maintainer: Samuel Tonini
;; Version: 0.0.1
;; URL:
;; Keywords: git, gitconfig

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;;   Manual Installation:
;;
;;    (add-to-list 'load-path "~/path/to/gitconfig.el/")
;;    (require 'gitconfig)
;;    (global-gitconfig-mode)
;;
;;   Example code:
;;
;;    (gitconfig-set-variable "local" "project.author" "Samuel")
;;    (gitconfig-get-variable "local" "project.author")
;;    (gitconfig-delete-variable "local" "project.author")
;;
;;   Interesting variables are:
;;
;;       `gitconfig-git-command`
;;
;;            The shell command for <git>
;;
;;       `gitconfig-buffer-name`
;;
;;            Name of the <git> output buffer.
;;
;;   Interactive functions are:
;;
;;        M-x gitconfig-execute-command
;;
;;            Run `git config` with custom `arguments` and display it in buffer
;;
;;   Non-Interactive functions are:
;;
;;        `gitconfig-current-inside-git-repository-p`
;;
;;            <desc>
;;


;;; Code:

(defcustom gitconfig-git-command "git"
  "The shell command for git"
  :type 'string
  :group 'gitconfig)

(defvar gitconfig-buffer-name "*GITCONFIG*"
  "Name of the git output buffer.")

(defun gitconfig--get-keys (hash)
  "Return all keys for given `hash`."
  (let (keys)
    (maphash (lambda (key value) (setq keys (cons key keys))) hash)
    keys))

(defun gitconfig--get-buffer (name)
  "Get and kills a buffer if exists and returns a new one."
  (let ((buffer (get-buffer name)))
    (when buffer (kill-buffer buffer))
    (generate-new-buffer name)))

(defun gitconfig--buffer-setup (buffer)
  "Setup the gitconfig buffer before display."
  (display-buffer buffer)
  (with-current-buffer buffer
    (setq buffer-read-only nil)
    (local-set-key "q" 'quit-window)))

(defun gitconfig-current-inside-git-repository-p ()
  "Return `t` if `default-directory` is a `git` repository"
  (let ((inside-work-tree (shell-command-to-string
                           (format "%s rev-parse --is-inside-work-tree"
                                   gitconfig-command))))
    (string= (replace-regexp-in-string "\n" "" inside-work-tree nil t) "true")))

(defun gitconfig-path-to-git-repository ()
  "Return the absolute path of the current `git` repository"
  (let ((path-to-git-repo (shell-command-to-string
                           (format "%s rev-parse --show-toplevel"
                                   gitconfig-command))))
    (replace-regexp-in-string "\n" "" path-to-git-repo nil t)))

(defun gitconfig--execute-command (arguments)
  (unless (gitconfig-current-inside-git-repository-p)
    (user-error "Fatal: Not a git repository (or any of the parent directories): .git"))
  (shell-command-to-string (format "%s config %s" gitconfig-git-command arguments)))

(defun gitconfig-get-variables (location)
  "Get all variables for the given `location` and return a hash table
   with all varibales in it."
  (let ((config-string (gitconfig--execute-command (format "--%s --list" location)))
        (variable-hash (make-hash-table :test 'equal)))
    (setq config-string (split-string config-string "\n"))
    (delete "" config-string)
    (mapcar (lambda (x) (puthash (car (split-string x "="))
                                 (car (last (split-string x "=")))
                                 variable-hash)) config-string)
    variable-hash))

(defun gitconfig-set-variable (location name value)
  "Set a specific `location` variable with a given `name` and `value`"
  (unless (gitconfig-current-inside-git-repository-p)
    (user-error "Fatal: Not a git repository (or any of the parent directories): .git"))
  (let ((exit-status (shell-command
                      (format "%s config --%s --replace-all %s %s"
                              gitconfig-command location name value))))
    (unless (= exit-status 0)
      (user-error (format "Error: key does not contain a section: %s" name)))
    t))

(defun gitconfig-get-variable (location name)
  "Return a specific `location` variable for the given `name`"
  (when (string= name "")
    (user-error "Error: variable does not exist."))
  (let ((variable (gitconfig--execute-command (format "--%s --get %s" location name))))
    (when (string-match "^error: " variable)
      (user-error variable))
    (if (string-match "\n+" variable)
        (replace-match "" t t variable)
      variable)))

(defun gitconfig-delete-variable (location name)
  "Delete a specific `location` variable for the given `name`"
  (unless (gitconfig-current-inside-git-repository-p)
    (user-error "Fatal: Not a git repository (or any of the parent directories): .git"))
  (let ((exit-status (shell-command
                      (format "%s config --%s --unset-all %s"
                              gitconfig-command location name))))
    (unless (= exit-status 0)
      (user-error (format "Error: key does not contain a section: %s" name)))
    t))

(defun gitconfig-execute-command (arguments)
  "Run `git config` with custom `arguments` and display it in buffer"
  (interactive "Mgit config: ")
  (let ((buffer (gitconfig--get-buffer gitconfig-buffer-name)))
    (shell-command (format "%s config %s" gitconfig-git-command arguments) buffer)
    (gitconfig--buffer-setup buffer)))

(defun gitconfig-get-local-variables ()
  "Return all `--local` location variables as hash table"
  (gitconfig-get-variables "local"))

(defun gitconfig-get-global-variables ()
  "Return all `--global` location variables as hash table"
  (gitconfig-get-variables "global"))

(defun gitconfig-get-system-variables ()
  "Return all `--system` location variables as hash table"
  (gitconfig-get-variables "system"))

(defun gitconfig-get-local-variable (name)
  "Return a specific `--local` variable by the given `name`"
  (gitconfig-get-variable "local" name))

(defun gitconfig-get-global-variable (name)
  "Return a specific `--global` variable by the given `name`"
  (gitconfig-get-variable "global" name))

(defun gitconfig-get-system-variable (name)
  "Return a specific `--system` variable by the given `name`"
  (gitconfig-get-variable "system" name))
