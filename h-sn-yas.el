;;; h-sn-yasnippet.el --- Utilities to convert snippets from `yasnippet' to h-sn.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Hai Nguyen

;; Author: Hai Nguyen <h@z5131530>
;; Keywords: convenience

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;;
;;; This is a quick code to convert yasnippet snippets into h-sn snippets syntax.
;;;
;;; It does not work reliably at the moment.


;;; Code:

;;tested on: $1  ${1} ${2:abc} ${3:`abc`}
(defun h/sn-yas-replace ()
  (interactive)
  (cl-loop with non-backslash = nil
           with field-num = nil
           with field-value = nil
   for pair in '(("\\([^\\]\\)\\${?\\([0-9]+\\)\\(\\(:.+?\\)?}\\)?" "\\1`\\2"))
         do
         (progn
           (goto-char (point-min))
           (while (search-forward-regexp (car pair) nil t)
             ;; (message "match 4: %s" (setf field-value (match-string 4)))
             (setf field-value
                   (if (stringp field-value)
                       (if (string-match-p field-value "^\\s-*:\\s-*`\\(.+?\\)`\\s-*$")
                           (replace-regexp-in-string
                            "^\\s-*:\\s-*`\\(.+?\\)`\\s-*$" ":\\1"
                            (or (match-string 4) ""))
                         (concat "\"" field-value "\""))
                     "")) ; (("`abc`"))
             (replace-match (cadr pair))
             (insert field-value "`")))))


(defconst *h/sn-files-list*
  (cl-loop for dir in yas-snippet-dirs append
           (cl-loop for file in
                    (h/list-files dir :recursive t :exclude-directories t)
                    when (string-match-p "/[^.][^/]+$" file)
                    collect file)))

(shell-command "cd /home/h/.emacs.d/ ; rm -rf snippets ; tar -xf /home/h/.emacs.d/snippets.tar.gz")

(cl-loop for file in *h/sn-files-list* do
         (with-current-buffer (find-file file)
           (goto-char (point-min))
           (search-forward "# --")
           (forward-line)
           (h/sn-yas-replace)
           (save-buffer 0)
           (kill-buffer (current-buffer))))


(provide 'h-sn-yasnippet)
;;; h-sn-yasnippet.el ends here
