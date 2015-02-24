;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp -*-
;;;
;;; unix-opts - a minimalistic parser of command line options.
;;;
;;; Copyright (c) 2015 Mark Karpov
;;;
;;; Permission is hereby granted, free of charge, to any person obtaining a
;;; copy of this software and associated documentation files (the
;;; "Software"), to deal in the Software without restriction, including
;;; without limitation the rights to use, copy, modify, merge, publish,
;;; distribute, sublicense, and/or sell copies of the Software, and to
;;; permit persons to whom the Software is furnished to do so, subject to
;;; the following conditions:
;;;
;;; The above copyright notice and this permission notice shall be included
;;; in all copies or substantial portions of the Software.
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
;;; OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
;;; LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
;;; OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
;;; WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(defpackage   :unix-opts
  (:nicknames :opts)
  (:use       #:common-lisp)
  (:export    #:define-opts
              #:argv
              #:get-opts
              #:describe)
  (:shadow    #:describe))

(in-package #:unix-opts)

(defclass option ()
  ((name
    :initarg  :name
    :accessor name
    :documentation "keyword that will be included in list returned by GET
function if this option is given by user")
   (description
    :initarg  :description
    :accessor description
    :documentation "description of the option")
   (short
    :initarg  :short
    :initform nil
    :accessor short
    :documentation "NIL or single char - short variant of the option")
   (long
    :initarg  :long
    :initform nil
    :accessor long
    :documentation "NIL or long char - long variant of the option")
   (arg-parser
    :initarg  :arg-parser
    :initform nil
    :accessor arg-parser
    :documentation "if not NIL, this options requires an argument, it will
be parsed with this function"))
  (:documentation "representation of an option"))

(defparameter *options* nil
  "list of all defined options")

(defun add-option (name desc &rest rest)
  (let ((short      (find-if #'characterp rest))
        (long       (find-if #'stringp    rest))
        (arg-parser (find-if #'functionp  rest)))
    (unless (or short long)
      (error "at least one form of the option must be provided"))
    (push (make-instance 'option
                         :name        name
                         :description desc
                         :short       short
                         :long        long
                         :arg-parser  arg-parser)
          *options*)))

(defmacro define-opts (&rest descriptions)
  "Define command line options. DESCRIPTIONS must be a list, where every
element is also a list. CAR of this list must be a keyword denoting name of
the option. CADR of this list must be a string describing the option. Next,
there may be a character (short option) and/or string (long option). If
particular option should take an argument, you may add a function that will
be called to parse the argument in form of string into your desired type."
  `(dolist (description ',descriptions)
     (apply #'add-option description)))

(defun argv ()
  "Return list of program's arguments, including command used to execute the
program as first elements of the list."
  #+abcl      ext:*command-line-argument-list*
  #+allegro   sys:command-line-arguments
  #+:ccl      ccl:*command-line-argument-list*
  #+clisp     ext:argv
  #+clozure   ccl::command-line-arguments
  #+cmu       extensions:*command-line-words*
  #+ecl       (ext:command-args)
  #+gcl       si:*command-args*
  #+lispworks system:*line-arguments-list*
  #+sbcl      sb-ext:*posix-argv*)

(defun shortp (opt)
  "Return option if OPT is a short option and NIL otherwise."
  (and (= (length opt) 2)
       (char=  #\- (char opt 0))
       (find (char opt 1) *options* :test #'char= :key #'short)))

(defun longp (opt)
  "Return option if OPT is a long option and NIL otherwise."
  (and (> (length opt) 2)
       (char= #\- (char opt 0))
       (char= #\- (char opt 1))
       (find (subseq opt 2) *options* :test #'string= :key #'long)))

(defun get-opts (&optional options)
  "Parse command line options. If OPTIONS is given, it should be a list to
parse. If it's not given, the function will use ARGV function to get list of
command line arguments. Return two values: list that contains keywords
associated with command line options with DEFINE-OPTS macro, and list of
free arguments. If some option requires an argument, you can use GETF to
test presence of the option and get its argument if the option is present."
  (flet ((split-short-opts (arg)
           (if (and (> (length arg) 1)
                    (char=  #\- (char arg 0))
                    (char/= #\- (char arg 1)))
               (mapcar (lambda (c) (format nil "-~c" c))
                       (cdr (coerce arg 'list)))
               (list arg))))
    (do ((tokens (mapcan #'split-short-opts
                         (or options (cdr (argv))))
                 (cdr tokens))
         pending-arg ; don't forget about --file=blah syntax
         result)
        ((null tokens) (nreverse result))
      ;; stuff
      )))

(defun describe (&key alpha-sort)
  "Return string describing options of the program that were defined with
DEFINE-OPTS macro previously. If argument ALPHA-SORT is given and it's not
NIL, descriptions of the options will be sorted alphabetically."
  (let ((opts (funcall (if alpha-sort #'reverse #'identity)
                       *options*)))
    (with-output-to-string (stream)
      (dolist (opt opts)
        (with-slots (short long description) opt
          ;; TODO: print arguments too
          (format stream "  ~25a~a~%"
                  (concatenate 'string
                               (if short (format nil "-~c" short) "")
                               (if (and short long) ", " "")
                               (if long  (format nil "--~a" long) ""))
                  description))))))
