- [h/sn - a simple text-snippet library](#org7a03f6d)
- [Mechanism](#orgf5bc725)
- [Limitations](#org0e04923)
- [Installation](#orgbe55a5f)
- [Usage](#orgca284c1)
- [Reference](#orgf173a28)

**Note**: this project won't be actively maintained due to my lack of time.


<a id="org7a03f6d"></a>

# h/sn - a simple text-snippet library

This is an exercise for me to learn Emacs Lisp by building a text-based snippet library based on the idea (and the code of) \`yasnippet'.


<a id="orgf5bc725"></a>

# Mechanism

This package is based on yasnippet's concepts of mode-based snippet directory structure. Snippet expansion is based on the concept of expanding special text fields in the snippet, which is either an Emacs Lisp code or a numbered variable.

However, the difference of this library from yasnipet is that the notation for the field is more uniform (just using the back-tick form, eg. \`(some elisp here)\` and \`1\` instead of $1, and \`1:some elisp here\` instead of ${1:\`some elisp here\`}, and \`1:"some string to prompt the user for input"\` instead of ${1:some string}). This simplify the code and the snippets syntax.

For convenience, this library used yasnippet's code for fetching snippets and for overloading the Tab key, although it can be further developed to runs on its own.


<a id="org0e04923"></a>

# Limitations

-   Borrowing yasnippet's code.


<a id="orgbe55a5f"></a>

# Installation

Let <path-to-h-sn-directory> be the path to where h-sn-el gets downloaded to, then:

```emacs-lisp
(add-to-list 'load-path <path-to-h-sn-directory>)
(require 'h-sn)
(h/global-sn-mode 1) ; for global mode, or
(h/sn-minor-mode 1) ; for buffer-local mode
```


<a id="orgca284c1"></a>

# Usage

There is no default key-mapping for this mode, so as to avoid it overloading user's current key-map.

However, just like yasnippet, one can map it to the <tab> key to expand snippet keyword before point, or search and insert a snippet at point via calling the command \`h/sn-insert'. A simple key-mapping for this can be:

```emacs-lisp
(define-key h/sn-minor-mode-map (kbd "C-c i") #'h/sn-insert)
(define-key h/sn-minor-mode-map (kbd "<tab>")  #'h/sn-expand-maybe)
```

A utility "h-sn-yas.el" is provided to help user convert from yasnippet snippets to the snippet format of this system. However, the code is still a kind of "more or less" working.


<a id="orgf173a28"></a>

# Reference

-   [yasnippet](http://github.com/joaotavora/yasnippet)