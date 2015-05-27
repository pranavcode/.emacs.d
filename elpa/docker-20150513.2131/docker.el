;;; docker.el --- Interact with Docker -*- lexical-binding: t -*-

;; Copyright (C) 2015 Mario Rodas <marsam@users.noreply.github.com>

;; Author: Mario Rodas <marsam@users.noreply.github.com>
;; URL: https://github.com/emacs-pe/docker.el
;; Package-Version: 20150513.2131
;; Keywords: docker, convenience
;; Version: 0.1
;; Package-Requires: ((emacs "24") (cl-lib "0.5"))

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; [![Travis build status](https://travis-ci.org/emacs-pe/docker.el.svg?branch=master)](https://travis-ci.org/emacs-pe/docker.el)
;;
;; `docker.el' offers a TRAMP method for Docker containers.
;;
;; > **NOTE**: `docker.el' relies in the `docker exec` command.
;; > Tested with docker version 1.6.x but should work with versions >1.3

;;; Code:
(eval-when-compile (require 'cl-lib))

(require 'tramp)
(require 'tramp-cache)

(defgroup docker nil
  "Interact with Docker from Emacs."
  :prefix "docker-"
  :group 'applications)

(defcustom docker-executable "docker"
  "Executable of docker."
  :type 'string
  :group 'docker)

;;;###tramp-autoload
(defconst docker-tramp-completion-function-alist
  '((docker-parse-running-containers  ""))
  "Default list of (FUNCTION FILE) pairs to be examined for docker method.")

;;;###tramp-autoload
(defconst docker-tramp-method "docker"
  "Method to connect docker containers.")

(defun docker--running-containers ()
  "Collect docker running containers."
  (cl-loop for line in (cdr (process-lines docker-executable "ps"))
           collect (split-string line "[[:space:]]+" t)))

(defun docker-parse-running-containers (&optional ignored)
  "Return a list of (user host) tuples.

TRAMP calls this function with a filename which is IGNORED.  The
user is an empty string because the docker TRAMP method uses bash
to connect to the default user containers."
  (mapcar (lambda (info) (list "" (car info)))
          (docker--running-containers)))

;;;###autoload
(defun docker-tramp-cleanup ()
  "Cleanup TRAMP cache for docker method."
  (interactive)
  (let ((containers (mapcar 'car (docker--running-containers))))
    (maphash (lambda (key _value)
               (when (and (vectorp key)
                          (string-equal docker-tramp-method (tramp-file-name-method key))
                          (not (member (tramp-file-name-host key) containers)))
                 (remhash key tramp-cache-data)))
             tramp-cache-data))
  (setq tramp-cache-data-changed t)
  (if (zerop (hash-table-count tramp-cache-data))
      (ignore-errors (delete-file tramp-persistency-file-name))
    (tramp-dump-connection-properties)))

;;;###tramp-autoload
(add-to-list 'tramp-methods
             `(,docker-tramp-method
               (tramp-login-program      ,docker-executable)
               (tramp-login-args         (("exec" "-it") ("%h") ("bash")))
               (tramp-remote-shell       "/bin/sh")
               (tramp-remote-shell-args  ("-i" "-c"))))

;;;###tramp-autoload
(eval-after-load 'tramp
  '(tramp-set-completion-function docker-tramp-method docker-tramp-completion-function-alist))

(provide 'docker)

;;; docker.el ends here
