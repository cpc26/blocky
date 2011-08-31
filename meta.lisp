;;; meta.lisp --- visual lisp macros for a blocky-in-blocky funfest

;; Copyright (C) 2011  David O'Toole

;; Author: David O'Toole <dto@ioforms.org>
;; Keywords: 

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

(in-package :blocky)

;;; Sending to a referenced object 

(defmacro define-visual-macro ((name super &rest fields)
		     &rest body)
  "Define a visual block element called NAME.
The argument SUPER should be the name of the base prototype of the
resulting block. FIELDS should be a list of field descriptors as given
to `define-prototype'. The BODY forms are evaluated when the resulting
block is recompiled; therefore the BODY forms define the output of the
recompilation."
    `(progn 
       (define-block (,name :super ,super) ,@fields)
       (define-method recompile ,name () ,@body)
       (define-method evaluate ,name ()
	 (eval (recompile self)))))

;;; Use quote to prevent evaluation

(define-visual-macro (quote list
			    (category :initform :operators))
		     ;; i think this is wrong
		     `(quote ,(mapcar #'recompile %inputs)))

;;; Send the messages in a list to the referent of the first element

(define-visual-macro (prog0 list
  (category :initform :structure)))

(define-method evaluate prog0 ()
  (destructuring-bind (target &rest body) %inputs
    (mapcar #'evaluate (rest %inputs))
      (with-target (evaluate target)
	(mapc #'evaluate body))))

(define-method initialize prog0 (&key target inputs)
  ;; (assert (blockyp target))
  ;; (assert (consp inputs))
  (super%initialize self)
  (let ((ref (new reference target)))
    (pin ref) ;; don't allow ref to be removed
    (setf %inputs (cons ref inputs))))

;;; Defining blocks visually

(define-visual-macro 
    (define-block list)
    ;; spit out a define-block
    (let ((fields (mapcar #'recompile (rest %inputs))))
      (destructuring-bind (name value)
	  (mapcar %recompile (field-value :inputs (first %inputs)))
	(append (list 'define-block 
		      (make-symbol name)
		      :super (make-prototype-id super))
		fields))))

(define-method initialize define-block ()
  (let ((header
	  (new send 
	       :active-on-click nil
	       :prototype (object-name (find-super self))
	       :method :do-define-block
	       :label "define block"
	       :target self)))
    (super%initialize self header)
    (pin header)))

(define-method (do-define-block :category :system) define-block
    ((name string :default "") 
     (super string :default "block"))
  ;; skip leading widget
  (let ((fields (mapcar #'recompile (rest %inputs))))
    (eval `(define-block 
	       ,(list (make-symbol name) 
		      :super (make-prototype-id super))
	     ,@fields))))

;;; Defining fields 

(define-visual-macro (field block
	    (category :initform :variables))
	   (destructuring-bind (name value) 
	       (mapcar #'recompile %inputs)
	     (list name :initform value)))

(define-method initialize field ()
  (super%initialize self 
		    (new string :label "field")
		    (new socket :label "default")))

(define-method accept field (thing)
  (declare (ignore thing))
  nil)

;;; Arguments

(define-visual-macro 
    (argument block
	      (category :initform :variables))
    (destructuring-bind (name type default) 
	(mapcar #'recompile %inputs)
      (list (make-symbol name) type :default default)))

(define-method initialize argument ()
  (super%initialize 
   (new string :label "name")
   (new entry :label "type")
   (new string :label "default")))


;;; Defining methods

(define-visual-macro (method tree)
	   (destructuring-bind (name prototype definition) 
	       (mapcar #'recompile %inputs)
	     (let ((method-name (make-symbol (first name)))
		   (prototype-id (make-prototype-id prototype)))
	       (append (list 'define-method method-name prototype-id)
		       (first definition)))))

(define-method initialize method ()
  (super%initialize self
		    :locked t
		    :expanded t
		    :label "define method"
		    :inputs
		    (list
		     (new string :label "name")
		     (new tree :label "for block"
			       :inputs (list (new string :value "name" :label "")))
		     (new tree :label "definition" :inputs (list (new block))))))


;;; meta.lisp ends here