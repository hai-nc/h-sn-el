;;; h-sn.el --- A text-based snippet system based on the library `yasnippet'.  -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Hai Nguyen

;; Author: Hai Nguyen
;; Keywords: convenience, tools
;; URL: <https://gitlab.com/haicnguyen/h-sn-el.git>, <https://github.com/haicnguyen/h-sn-el>

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

;; Please refer to the README.md file.

;;; Code:
(defconst h/sn-version "0.0.1")


(require 'yasnippet)


;;; * Declarations

(defconst h/sn-regexp--bob-or-backslash "\\(^\\|[^\\]\\)"
    "A helper regexp to scan for the symbol of the start of the embedded code, which is not preceded by a backslach in front or which starts from the beginning of buffer.")

(defconst h/sn-regexp-backtick (concat h/sn-regexp--bob-or-backslash
                                         "`\\([0-9]*\\)?:?\\(.*?[^\\]\\)?`")
    "This backtick form covers all cases of numbered field (like $1 in `yasnippet'), plain elisp form (e.g. \\`(goto-char 1)\\` in `yasnippet'), and numbered field containing plain elisp form (e.g. ${1:`elisp form`}), and numbered field containing prompt string (e.g. ${1:prompt}). For detail implementation pleae refer to `h/sn--parse'.

Examples: `1`, `1:`, `1:(message \"Hello world!\")`, `1(message \"Hello world!\")` , `1t`")


;;; * Helper functions

(defun h/make-point-marker (type)
  "Create a point-marker of TYPE 'start or 'end."
  (let ((marker (point-marker)))
    (set-marker-insertion-type marker type)
    marker))


(defun h/make-point-marker-start ()
  "Create a point-marker of TYPE 'start."
  (interactive)
  (h/make-point-marker nil))


(defun h/make-point-marker-end ()
  "Create a point-marker of TYPE 'end."
  (interactive)
  (h/make-point-marker t))


;;; * Fetching snippets

(defun h/sn--list-snippets (regexp major-mode-and-parents)
  "Returns the list of snippets whose filenames match the regexp REGEXP.

REGEXP: regular expression of the snippet name.
MAJOR-MODE-AND-PARENTS :: the stack of directory names."
  (cl-assert (listp major-mode-and-parents))
  (let ((major-mode-and-parents (copy-sequence major-mode-and-parents))
	(matched-list nil)
	)    
    (cl-loop
     for mode = nil
     while (> (length major-mode-and-parents) 0) do
     (setf mode (pop major-mode-and-parents)
           matched-list (append
	                 matched-list
	                 (cl-loop
	                  for x in (directory-files
			            (concat h/sn-dir mode "/") nil regexp)
	                  if (null (assoc x matched-list))
	                  collect (list x mode))))
     (setq major-mode-and-parents
	   (append
	    major-mode-and-parents
	    (h/sn-parent-modes mode))))
    matched-list))


(defun h/sn-list-parents (start-dir)
  "Fetch parent dirs specified in START-DIR."
  (let ((file (concat h/sn-dir start-dir "/" h/sn-parents-filename))
	(result-alist ()))
    (cl-loop when (file-exists-p file)
             collect (with-temp-buffer
	               (insert-file-contents file)
	               (split-string
	                (buffer-substring-no-properties (point-min) (point-max))
	                "[\n\r]" t
	                )))))


(defalias 'h/sn-reload #'yas-reload-all)


(defun h/sn--template-list-sorted ()
  "Return the list of current template structs."
  (require 'yasnippet)
  (let ((yas-snippet-tables (yas--get-snippet-tables)))
    (unless yas-snippet-tables
      (user-error "Cannot read `yas-snippet-tables' variable; is `yas-global-mode'  activated!?"))
    (sort (yas--all-templates yas-snippet-tables)
          #'(lambda (t1 t2) (< (length (yas--template-name t1))
                               (length (yas--template-name t2)))))))


(defun h/sn--template-get-content (keyword)
  "Find the content of the template whose name is KEYWORD, if found then returns the string content of that template."
  (cl-loop for template-struct in (h/sn--template-list-sorted)
         when (string-equal (yas--template-name template-struct) keyword)
         do (return (yas--template-content template-struct))))



(defun h/sn--template-completing-read ()
  (let ((all-templates (h/sn--template-list-sorted)))
    (and (cl-rest all-templates)
         (yas--prompt-for-template all-templates))))


;;; * Expanding snippets
;;
;; not working for *all* cases: failed to get the correct yielding key-binding for help buffer (it keeps returning "indent-for-tab-command" instead of "next-button"!)
(defun h/sn-expand-maybe ()
  (interactive "*")
  (let ((p0 (point))
        sym beg end
        (bounds (bounds-of-thing-at-point 'symbol))
        template)
    (when (consp bounds)
      (setf beg (car bounds)
            end (cdr bounds)
            sym (buffer-substring-no-properties beg end)
            template (h/sn--template-get-content sym)))
    (if template
        (progn
          (delete-region beg end)
          (let ((template-beg (h/make-point-marker-start))
                (template-end (h/make-point-marker-end)))
            (insert template)
            (h/sn-expand-region template-beg template-end)))
      ;; temporarily turn off this mode to fall back to another mode's key:
      (let* ((lexical-binding t)
             (h/sn-minor-mode nil)
             (keys (this-single-command-keys))
             (command (or (key-binding keys t)
                          (key-binding (yas--fallback-translate-input keys)))))
        (message "command: %S" command)
        (when (commandp command) (call-interactively command))))))


(defun h/sn--field-next (bound)
  "Find the next field that match the regexp. Any literal backtick inside the form will need escaping, ie \"\\`\", to distinguish it from the backtick that bounds the regexp.

This regexp include all cases of numbered field (like $1 in `yasnippet'), plain elisp form (e.g. \\`(goto-char 1)\\` in `yasnippet'), and numbered field containing plain elisp form (e.g. ${1:`elisp form`}), and numbered field containing prompt string (e.g. ${1:prompt}). For detail implementation pleae refer to `h/sn--field-parse'.

Examples: `1`, `1:`, `1:(message \"Hello world!\")`, `1(message \"Hello world!\")` , `1t`"
  (let ((beginning-of-buffer-p (bobp))
        field-beg field-end)
    (or beginning-of-buffer-p ; if backward-char here, maybe gets user-error
        (backward-char 1)) ; search regexp below looking at char *BEFORE* start pos
    (when (search-forward-regexp (if beginning-of-buffer-p "`" "\\([^\\]\\)`")
                                 bound t 1)
      (setf field-beg (1- (match-end 0)))
      (if (search-forward-regexp "[^\\]`" bound t 1)
          (setf field-end (match-end 0))
        (setf field-beg nil
              field-end nil)))
    (values field-beg field-end)))

(defun h/sn--empty-string-p (str)
  (and (stringp str)
       (string-match-p "" str)))

(defun h/sn--field-parse (field-beg field-end)
  (let ((start-pos (point))
        number-str form-str)
    (goto-char field-beg)
    (search-forward-regexp "`\\([0-9]+\\)" field-end t)
    (setf number-str (match-string 1))
    (if (h/sn--empty-string-p number-str)
        (when (= (char-after) ?:) (forward-char))
      (forward-char) ; no number found -> skip the starting "`" char
      )
    (setf form-str (buffer-substring-no-properties (point) (1- field-end)))
    (goto-char start-pos)
    (values number-str form-str)))


(cl-defstruct h/sn-field
  (number nil)
  (form nil)
  (marker nil))


(defun h/sn--field-evaluate (field)
  (let ((field-form (h/sn-field-form field)))
    (and (stringp field-form)
       (null (zerop (length field-form)))
       (if (string-match-p "^\\s-*\".+" field-form)
           (read-string field-form)
         (h/sn--eval field-form)))))


(defun h/sn-expand-region (start end &optional last-result)
  "Scanning from START to END and expanding all backtick forms.

A field is a backtick form, which is described by `h/sn-regexp-backtick'.

If a field is found, this evaluates it and if the result is non-nil that result will be inserted into the current buffer."
  (let ((last-code-end (h/make-point-marker-end)) ; to track end of current code position
        (marker-$0 end)
        field-beg field-end field-number field-form
        field-value-global
        fields
        (numbered-fields (make-hash-table :test #'eql)))
    (goto-char start)
    (while (cl-multiple-value-bind (next-beg next-end) (h/sn--field-next end)
             (and (number-or-marker-p next-beg)
                  (number-or-marker-p next-end))
             (setf field-beg next-beg
                   field-end next-end))
      (cl-multiple-value-bind (number-str form-str) (h/sn--field-parse
                                                     field-beg field-end)
        
      (setf field-number (and (stringp number-str)
                              (string-match-p "^[0-9]+$" number-str)
                              (string-to-number (substring-no-properties
                                                 number-str)))
            field-form form-str))
      
      (delete-region field-beg field-end)
      ;; collecting all fields first, leaving marks in each, removing *ALL* of them from the buffer to avoid confusion of numbered fields when doing nested expansions, when reaching the end of this round go to each marker and evaluate
      ;;
      ;; this prevent the code to confuse fields of different scope in the nested expansion that have the same field number. 
      (push (make-h/sn-field :number field-number
                        :form field-form
                        :marker (h/make-point-marker-end))
            fields))

    ;; evaluate the un-numbered field first, starting from the beginning:
    (cl-loop
     with numbered-fields = nil
     with field = nil
     with field-value = nil
     until (zerop (length fields))
     do (progn
          (setf field (pop fields)
                field-number (h/sn-field-number field))
          (goto-char (h/sn-field-marker field))
          (if (numberp field-number)
              (push field numbered-fields)
            (setf field-value (h/sn--field-evaluate field))
            (when field-value (insert (format "%s" field-value)))))
     finally (setf fields (sort numbered-fields
                                (lambda (field1 field2)
                                  (let ((field-number1 (h/sn-field-number field1))
                                        (field-number2 (h/sn-field-number field2)))
                                    (cl-assert (numberp field-number1))
                                    (cl-assert (numberp field-number2))
                                    (or (< field-number1 field-number2)
                                        (and (= field-number1 field-number2)
                                             (null (h/sn-field-value field2)))))))))

    (cl-loop
     with last-field-value = nil
     with last-field-number = nil
     with field-number = nil
     with field-value = nil
     for field in fields do
     (progn
       (setf
        field-number (h/sn-field-number field)
        field-form (h/sn-field-form field))
       (when (null (numberp field-number))
         (error "Expecting remaining field to be numbered fieds, but this field is not!"))
       
       (goto-char (h/sn-field-marker field))
       
       (if (zerop field-number)
           (setf marker-$0 (point-marker))
         ;; else:
         (if (and last-field-number (= field-number last-field-number))
             (setf field-value last-field-value)
           (setf field-value (h/sn--field-evaluate field))))
       (setf last-field-value field-value
             last-field-number field-number)
       (when field-value (insert (format "%s" field-value))))
     finally (setf marker-$0 (point)))
       (goto-char (or marker-$0 last-code-end))
    ;; if last-result is given, return the result of evaluation of the last field.
       (and last-result field-value)))


;;; * Eval code in the backtick form
(defun h/sn--eval (code)
  "Eval the string CODE.

Side-effect: possible, since this function eval the CODE."
  (eval (car (read-from-string code))))


(defun h/sn--expand-second-pass (start end)
  "Scanning from START to END and expanding all numbered forms."
  (goto-char start)
  (let (code
        matchstring-full
        matchstring-2
        ;; The final position of the cursor in the target buffer
        (marker-$0 end)
        )
    (while (search-forward-regexp h/sn-regexp-number end t 1)
	  (setf code (match-string 3)
            matchstring-2 (match-string 2)
            matchstring-full (match-string 0))
      ;; got error "Args out of range" when putting a `read-string' form here.
      (replace-match (match-string 1))
      (if (string-match-p matchstring-2 "0")
          (setf marker-$0 (point-marker))
        (insert (read-string
                 (concat
                  (if (stringp code) code matchstring-full)
                  ": ")))))
    (goto-char marker-$0)))



;;; * User inferface

(defun h/sn-insert (&optional keyword)
  "Insert *and* expand the snippet."
  (interactive (list (yas--template-name (h/sn--template-completing-read))))
  (let ((start (h/make-point-marker-start))
        (end (h/make-point-marker-end))
        (content (h/sn--template-get-content keyword)))
    (if content
        (insert content) ; *SIDE-EFFECT: change position of marker END
      (user-error "h/sn-insert(): Cannot find snippet `%s' for mode `%s'" keyword major-mode))
    (h/sn-expand-region start end)))


;;; * Minor mode set up

(defvar h/sn-minor-mode-map (make-sparse-keymap))

(defgroup h/sn nil
  "Based on yankpad. Pasting snippets from an org-mode file."
  :group 'editing)

(define-minor-mode h/sn-minor-mode
  "Mode for editing the snippet file"
  :keymap h/sn-minor-mode-map
  :group 'h/sn
  ;; enable narrowing:
  )

(define-globalized-minor-mode h/global-sn-mode h/sn-minor-mode h/sn-minor-mode-on)

(defun h/sn-minor-mode-on ()
  (interactive)
  (h/sn-minor-mode 1))


(provide 'h-sn)
;;; h-sn.el ends here
