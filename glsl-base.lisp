(in-package #:glsl)

;;; definitions for CL macros supported by the shader DSL
;;;   (and maybe some extra utilities)

(defparameter *glsl-base-environment*
  (make-instance '3bgl-shaders::environment
                 :parent 3bgl-shaders::*cl-environment*))

(defclass glsl-walker (3bgl-shaders::cl-walker)
  ())


#++
(let ((a nil))
  (do-external-symbols (s (find-package :cl)
                          (sort a 'string<))
    (when (and (fboundp s) (not (special-operator-p s))
               (macro-function s))
      (push s a))))

;;; stuff that is (or at least could be) handled by compiler:
;;;   all args are (potentially) evaluated normally, etc
;;; AND, DECF, INCF, OR, 

;;; not implementing (either not meaningful/useful or too hard)
;;;   (clos, runtime exceptions, etc)
(loop for s in
      '(CALL-METHOD ASSERT CCASE CTYPECASE DEFCLASS DEFGENERIC
        DEFINE-CONDITION DEFINE-METHOD-COMBINATION DEFMETHOD
        DEFPACKAGE DESTRUCTURING-BIND DO-ALL-SYMBOLS
        DO-EXTERNAL-SYMBOLS DO-SYMBOLS ECASE ETYPECASE FORMATTER
        HANDLER-BIND HANDLER-CASE IGNORE-ERRORS IN-PACKAGE
        MULTIPLE-VALUE-BIND MULTIPLE-VALUE-LIST MULTIPLE-VALUE-SETQ
        NTH-VALUE PPRINT-EXIT-IF-LIST-EXHAUSTED PPRINT-LOGICAL-BLOCK
        PPRINT-POP PRINT-UNREADABLE-OBJECT PROG PROG* PUSHNEW
        RESTART-BIND RESTART-CASE TIME TRACE UNTRACE
        WITH-CONDITION-RESTARTS WITH-HASH-TABLE-ITERATOR
        WITH-COMPILATION-UNIT WITH-INPUT-FROM-STRING WITH-OPEN-FILE
        WITH-OPEN-STREAM WITH-OUTPUT-TO-STRING WITH-PACKAGE-ITERATOR
        WITH-SIMPLE-RESTART WITH-STANDARD-IO-SYNTAX)
      do (3bgl-shaders::add-macro
          s
          `(lambda (&rest r)
             (declare (ignore r))
             (error ,(format nil "~a not supported in GLSL" s)))
          :env *glsl-base-environment*))

;;; not sure if we will have some 'list' equivalent?
(loop for s in
      '(POP DOLIST PUSH REMF)
      do (3bgl-shaders::add-macro
          s
          `(lambda (&rest r)
             (declare (ignore r))
             (error ,(format nil "~a not supported in GLSL" s)))
          :env *glsl-base-environment*))


;;; maybe?
(loop for s in
      '(DECLAIM CHECK-TYPE DEFTYPE DEFINE-SETF-EXPANDER DEFSETF LAMBDA TYPECASE
        WITH-ACCESSORS WITH-SLOTS)
      do (3bgl-shaders::add-macro
          s
          `(lambda (&rest r)
             (declare (ignore r))
             (error ,(format nil "~a not supported in GLSL (yet?)" s)))
          :env *glsl-base-environment*))

;;; todo:
(defmacro %glsl-macro (name lambda-list &body body)
  `(let ((3bgl-shaders::*environment* *glsl-base-environment*))
     (3bgl-shaders::add-macro ',name
                              (lambda (form env)
                                (declare (ignorable env))
                                (destructuring-bind ,lambda-list
                                    (cdr form)
                                  ,@body)))))

(%glsl-macro case (&body body)
  (declare (ignore body))
  `(error "CASE not implemented yet for GLSL."))


(%glsl-macro cond (&body body)
  (if (eq (caar body) t)
      `(progn ,@(cdar body))
      `(if ,(caar body)
           (progn ,@(cdar body))
           ,@(when (cdr body)
               `((cond ,@(cdr body)))))))

(%glsl-macro define-compiler-macro (&body body)
  (declare (ignore body))
  `(error "DEFINE-COMPILER-MACRO not implemented yet for GLSL"))

(%glsl-macro define-modify-macro (&body body)
  (declare (ignore body))
  `(error "DEFINE-MODIFY-MACRO not implemented yet for GLSL"))

(%glsl-macro define-symbol-macro (name expansion)
  (3bgl-shaders::add-symbol-macro name expansion)
  nil)

(%glsl-macro defmacro (name lambda-list &body body)
  ;; fixme: extract docstrings/declarations from body
  #++(format t "define macro ~s~%" name)
  (3bgl-shaders::add-macro name
                           `(lambda (form env)
                              (declare (ignore env))
                              (destructuring-bind ,lambda-list
                                  (cdr form)
                                ,@body)))
  nil)

#++
(%glsl-macro defstruct (&body body)
  (declare (ignore body))
  `(error "DEFSTRUCT not implemented yet for GLSL"))

;;; no 'unbound' variables in GLSL, so requiring value arg, and
;;; not sure there is any distinction between DEFVAR and DEFPARAMETER
;;; in shaders, so just expanding to defparameter...
(%glsl-macro defvar (name value &optional docs)
  (declare (ignore docs))
  `(defparameter ,name ,value))

(%glsl-macro do (&body body)
  (declare (ignore body))
  `(error "DO not implemented yet for GLSL"))

(%glsl-macro do* (&body body)
  (declare (ignore body))
  `(error "DO* not implemented yet for GLSL"))

(%glsl-macro dotimes (&body body)
  (declare (ignore body))
  `(error "DOTIMES not implemented yet for GLSL"))

(%glsl-macro loop (&body body)
  (declare (ignore body))
  `(error "LOOP not implemented yet for GLSL"))

(%glsl-macro loop-finish (&body body)
  (declare (ignore body))
  `(error "LOOP-FINISH not implemented yet for GLSL"))

(%glsl-macro prog1 (first-form &body form*)
  (alexandria:with-gensyms (temp)
    `(let ((,temp ,first-form))
       ,@form*
       ,temp)))

(%glsl-macro prog2 (first-form second-form &rest form*)
  (alexandria:with-gensyms (temp)
    `(progn
       ,first-form
       (let ((,temp ,second-form))
         ,@form*
         ,temp))))

(%glsl-macro PSETF (&body body)
  (error "PSETF not implemented yet for GLSL")
  `(,@body))

(%glsl-macro PSETQ (&body body)
  (error "PSETQ not implemented yet for GLSL")
  `(,@body))

;; handle by compiler for now?
#++
(%glsl-macro return (&body body)
 `(,@body))

(%glsl-macro rotatef (&body args)
  (when (cdr args) ;; ignore it if 1 or fewer places
      (alexandria:with-gensyms (temp)
        `(let ((,temp ,(car args)))
           ,@(loop for (a . b) on args
                   while b
                   collect `(setf ,a ,(car b)))
           (setf ,(car (last args)) ,temp)
           ;; rotatef returns NIL
           nil))))

(%glsl-macro setf (&body pairs)
  ;; for now, just expand to a bunch of SETQ forms and hope the
  ;; compiler can deal with them
  ;; (probably implementing things like swizzles and maybe struct
  ;;  accesse at that level, so should be enough for a while, but
  ;;  will probably eventually want to be able to do stuff like
  ;;  (setf (ldb...) foo) etc.)
  (if (> (length pairs) 2)
      `(progn ,@(loop for (a b) on pairs by #'cddr
                      collect `(setq ,a ,b)))
      `(setq ,(first pairs) ,(second pairs))))

(%glsl-macro shiftf (&rest args)
  (alexandria:with-gensyms (temp)
    `(let ((,temp ,(car args)))
       ,@(loop for (a . b) on args
               while b
               collect `(setf ,a ,(car b)))
       ,temp)))

(%glsl-macro unless (a b)
  ;; not quite usual expansion, since we don't really have a "NIL" to return
  `(if (not ,a) (progn ,@b)))

(%glsl-macro when (a &rest b)
  `(if ,a (progn ,@b)))



;;; extra 'special forms' for GLSL stuff
;;;   probably expanded directly by compiler

#++
(3bgl-shaders::defwalker glsl-walker (defparameter name value &optional docs)
  (declare (ignore docs))
  `(:var ,name :init ,(3bgl-shaders::@ value)))

#++
(3bgl-shaders::defwalker glsl-walker (defconstant name value  &optional docs)
  (declare (ignore docs))
  `(:var ,name :init ,(3bgl-shaders::@ value) :qualifiers ,(list :const)))

#++
(3bgl-shaders::defwalker glsl-walker (cl:defun name lambda-list &body body+d)
  (multiple-value-bind (body declare doc) (alexandria:parse-body body+d)
    `(:function ,name :lambda-list ,lambda-list
      :declare ,@(when declare (list declare))
      :doc ,@(when doc (list doc))
      :body ,@(3bgl-shaders::@@ body))))

#++
(3bgl-shaders::defwalker glsl-walker (:function name &rest args &key body &allow-other-keys)
  (let ((walked (3bgl-shaders::@ body)))
    (when (not (equal walked body))
      (setf args (copy-list args))
      (setf (getf args :body) walked)))
  `(:var ,name ,@args))

#++
(3bgl-shaders::defwalker glsl-walker (:var name &rest args &key init &allow-other-keys)
  (let ((walked (3bgl-shaders::@ init)))
    (when (not (equal walked init))
      (setf args (copy-list args))
      (setf (getf args :init) walked)))
  `(:var ,name ,@args))


;;; translate into IR

(cl:defun filter-progn (x)
  (loop for i in x
        ;; if we have a progn in the body, just expand the contents
        ;; (but not something with progn as a mixin)
        when (eq (class-of i) (find-class '3bgl-shaders::progn-body))
          append (filter-progn (3bgl-shaders::body i))
        else
          if i
            collect i))

(3bgl-shaders::defwalker glsl-walker (defparameter name value &optional docs)
  (declare (ignore docs))
  (3bgl-shaders::add-variable name (3bgl-shaders::@ value)))

(3bgl-shaders::defwalker glsl-walker (cl:defconstant name value &optional docs)
  (declare (ignore docs))
  (3bgl-shaders::add-variable name
                              (3bgl-shaders::@ value)
                              :type '3bgl-shaders::constant-binding))

(3bgl-shaders::defwalker glsl-walker (%defconstant name value type)
  (3bgl-shaders::add-variable name
                              (3bgl-shaders::@ value)
                              :type '3bgl-shaders::constant-binding
                              :value-type type))

(3bgl-shaders::defwalker glsl-walker (cl:defun name lambda-list &body body+d)
  (3bgl-shaders::process-type-declarations-for-scope
   (multiple-value-bind (body declare doc)
       (alexandria:parse-body body+d :documentation t)
     (3bgl-shaders::add-function name lambda-list
                                 (filter-progn (3bgl-shaders::@@ body))
                                 :declarations declare :docs doc))))

#++
(3bgl-shaders::defwalker glsl-walker (let (&rest bindings) &rest body+d)
  (multiple-value-bind (body declare)
      (alexandria:parse-body body+d)
    (make-instance
     '3bgl-shaders::binding-scope
     :bindings (loop for (n i) in bindings
                     collect (make-instance '3bgl-shaders::local-variable
                                            :name n
                                            :init (3bgl-shaders::@ i)
                                            :value-type t))
     :declarations declare
     :body (3bgl-shaders::@@ body))))

(3bgl-shaders::defwalker glsl-walker (let (&rest bindings) &rest body+d)
  (3bgl-shaders::process-type-declarations-for-scope
   (multiple-value-bind (body declare)
       (alexandria:parse-body body+d)
     (let ((l (make-instance
               '3bgl-shaders::binding-scope
               :bindings (loop for (n i) in bindings
                               collect (make-instance
                                        '3bgl-shaders::local-variable
                                        :name n
                                        :init (3bgl-shaders::@ i)
                                        :value-type t))
               :declarations declare
               :body nil)))
       (setf (3bgl-shaders::body l)
             (3bgl-shaders::with-lambda-list-vars (l)
               (3bgl-shaders::@@ body)))
       l))))

(3bgl-shaders::defwalker glsl-walker (let* (&rest bindings) &rest body+d)
  (multiple-value-bind (body declare)
      (alexandria:parse-body body+d)
    (3bgl-shaders::process-type-declarations-for-scope
     (3bgl-shaders::with-environment-scope ()
       (make-instance
        '3bgl-shaders::binding-scope
        :bindings (loop for (n i) in bindings
                        for b = (make-instance
                                 '3bgl-shaders::local-variable
                                 :name n
                                 :init (3bgl-shaders::@ i)
                                 :value-type t)
                        collect b
                        do (3bgl-shaders::add-variable n i :binding b))
        :declarations declare
        :body (3bgl-shaders::@@ body))))))

(3bgl-shaders::defwalker glsl-walker (progn &body body)
  (make-instance '3bgl-shaders::explicit-progn
                 :body (filter-progn (3bgl-shaders::@@ body))))

(3bgl-shaders::defwalker glsl-walker (setq &rest assignments)
  (cond
    ;; if we have multiple assignments, expand to a sequence of 2 arg setq
    ((> (length assignments) 2)
     (3bgl-shaders::walk `(progn ,@(loop for (a b) on assignments by #'cddr
                           collect `(setq a b)))
                         3bgl-shaders::walker))
    ;; single assignment
    ((= (length assignments) 2)
     (let* ((binding (3bgl-shaders::@ (first assignments)))
            (value (second assignments)))
       (assert (typep binding '3bgl-shaders::place))
       (make-instance '3bgl-shaders::variable-write
                      :binding binding
                      :value (3bgl-shaders::@ value))))
    (t (error "not enough arguments for SETQ in ~s?" assignments))))

(3bgl-shaders::defwalker glsl-walker (if a b &optional c)
  (make-instance '3bgl-shaders::if-form
                 :test (3bgl-shaders::@ a)
                 :then (3bgl-shaders::@ b)
                 :else (3bgl-shaders::@ c)))


;; function application
(defmethod 3bgl-shaders::walk-cons (car cdr (walker glsl-walker))
  ;; should have already expanded macros/local functions by now,
  ;; so anything left is a function call of some sort
  ;; we also handle a few special cases here for now:
  ;;  symbols starting with #\. are treated as struct slot accessors/swizzle
  ;;  aref forms are converted specially
  (let ((binding (3bgl-shaders::get-function-binding car)))
    #++(format t "~&looking up binding ~s got ~s~%" car binding)
    (cond
      ((typep binding '3bgl-shaders::function-binding-function)
       (make-instance '3bgl-shaders::function-call
                      :function binding
                      :arguments (mapcar (lambda (x)
                                           (3bgl-shaders::walk x walker))
                                         (funcall (3bgl-shaders::expander binding)
                                                  cdr))))
      ((eq car 'aref)
       (make-instance '3bgl-shaders::array-access
                      :binding (3bgl-shaders::walk (first cdr) walker)
                      :index (3bgl-shaders::walk (second cdr) walker)))
      ;; not sure about syntax for slot/swizzle, for now
      ;; trying magic .slot accessors
      ;; and (@ struct slot) style...
      ((eq car '@)
       (make-instance '3bgl-shaders::slot-access
                      :binding (3bgl-shaders::walk (first cdr) walker)
                      :field (second cdr)))
      ((and (symbolp car) (char= (char (string car) 0) #\.))
       (make-instance '3bgl-shaders::slot-access
                      :binding (3bgl-shaders::walk (first cdr) walker)
                      :field (subseq (string car) 1)))
      (t
       (call-next-method)))))

;; literals and variable access
(defmethod 3bgl-shaders::walk (form (walker glsl-walker))
  ;; symbol macros should already be expanded, so nothing left but
  ;; literals, variables and constants
  ;; (would be nice to expand constants inline, but we might not
  ;;  know the actual value yet, and the form used to initialize the constant
  ;;  might be expensive to evaluate repeatedly)
  (let ((binding (if (symbolp form)
                     (3bgl-shaders::get-variable-binding form)
                     form)))
    (if (typep binding '3bgl-shaders::binding)
        (make-instance '3bgl-shaders::variable-read
                       :binding binding)
        form)))



#++
(let ((3bgl-shaders::*environment*
        (make-instance '3bgl-shaders::environment
                       :parent *glsl-base-environment*)))
  (3bgl-shaders::walk '(progn
                        (defmacro do-stuff (a)
                          `(doing-stuff ,a))
                        (cond
                          ((= foo 1)
                           (do-stuff foo)
                           (more foo = 1))
                          ((= bar 2))
                          (t (default stuff))))
                      (make-instance '3bgl-shaders::cl-walker)))


;;; some more internal functions, that aren't in the CL package
(let ((3bgl-shaders::*environment* *glsl-base-environment*))
  (3bgl-shaders::add-internal-function '<< '(integer count))
  (3bgl-shaders::add-internal-function '>> '(integer count))
  (3bgl-shaders::add-internal-function 'return '(value))

)

;;; start defining some glsl functions
(%glsl-macro expt (a b)
  `(pow ,a ,b))

(macrolet
    ((add-builtins (&rest definitions)
       `(progn
          ,@(loop for (%name lambda-list return types) in definitions
                  for name = (if (consp %name) (car %name) %name)
                  for glsl-name = (if (consp %name) (cadr %name) nil)
                  collect
                  `(setf (gethash ',name (3bgl-shaders::function-bindings
                                          3bgl-shaders::*environment*))
                         (make-instance  '3bgl-shaders::builtin-function
                                         :name ',name
                                         :glsl-name ',glsl-name
                                         :lambda-list ',lambda-list
                                         ;; todo: add type info
                                         :return-type ,return)))))
     (builtin-vars (&rest definitions)
       `(progn
          ,@(loop for (stage dir %name type) in definitions
                  for name = (if (consp %name) (car %name) %name)
                  for glsl-name = (if (consp %name) (cadr %name) nil)
                  collect
                  `(setf (gethash ',name (3bgl-shaders::variable-bindings
                                          3bgl-shaders::*environment*))
                         (make-instance '3bgl-shaders::binding
                                        :name ',name
                                        :glsl-name ',glsl-name
                                        :value-type ,type))))))
 (let ((3bgl-shaders::*environment* *glsl-base-environment*))
   (add-builtins
    ((texture-2d "texture2D") (sampler uv) :vec4 (:sampler2D :vec))
    (mat2 (???) :mat2 (???))
    (mat2x3 (???) :mat2x3 (???))
    (mat2x4 (???) :mat2x4 (???))
    (mat3x2 (???) :mat3x2 (???))
    (mat3 (???) :mat3 (???))
    (mat3x4 (???) :mat3x4 (???))
    (mat4x2 (???) :mat4x2 (???))
    (mat4x3 (???) :mat4x3 (???))
    (mat4 (???) :mat4 (???))
    (vec2 (???) :vec2 (???))
    (vec3 (???) :vec3 (???))
    (vec4 (???) :vec4 (???))
    (normalize (vec) :vec (:vec))
    (length (vec) :float (:vec))
    (min (a b) :float (:float :float))
    (max (a b) :float (:float :float))
    (dot (a b) :float (:vec :vec))
    (abs (a) :float (:float))
    (sqrt (a) :float (:float))
    (pow (a b) :float (:float))
    (floor (a) :gentype (:gentype))
    (fract (a) :gentype (:gentype))
    (less-than (a b) :gentype (:gentype :gentype))
    ;; GLSL 'step' instead of CL STEP
    (step (x a b) :gentype (:gentype :gentype :gentype))
    (clamp (a b) :gentype (:gentype :gentype))
    (noise4 (a) :vec4 (:gentype))
    (cross (a b) :vec (:vec :vec))
    (transpose (x) :mat (:mat))
    ((emit-vertex "EmitVertex") () :void ())
    ((end-primitive "EndPrimitive") () :void ())
    (reflect (a b) :vec3 (:vec3 :vec3))
    ((smooth-step "smoothstep") (edge0 edge1 x) :gentype (:gentype :gentype :float))
    )
   ))

;; fixme: this should probably use a weak hash table
(cl:defparameter *package-environments* (make-hash-table))

(cl:defun ensure-package-environment (package)
  (or (gethash package *package-environments*)
      (setf (gethash package *package-environments*)
            (make-instance '3bgl-shaders::environment
                           ;; todo: make default parent environment
                           ;; configurable?
                           :parent *glsl-base-environment*))))

(cl:defun call-with-package-environment (thunk &key (package *package*))
  (let ((3bgl-shaders::*environment* (ensure-package-environment package)))
    (funcall thunk)))

(cl:defmacro with-package-environment (() &body body)
  `(call-with-package-environment (lambda () ,@body)))

;;; api for defining GLSL code from CL code
;; (as opposed to compiling a block of GLSL code as GLSL code, which can
;;  just use DEFUN etc directly)

(cl:defmacro glsl-defun (name args &body body)
  `(with-package-environment ()
     (3bgl-shaders::walk '(cl:defun ,name ,args ,@body)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro glsl-defconstant (name value type)
  `(with-package-environment ()
     (3bgl-shaders::walk '(%defconstant ,name ,value ,type)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro glsl-interface (name (&rest args &key in out uniform) &body slots)
  (declare (ignore in out uniform))
  `(with-package-environment ()
     (3bgl-shaders::walk '(interface ,name ,args ,@slots)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro glsl-attribute (name type &rest args &key location)
  (declare (ignore location))
  `(with-package-environment ()
     (3bgl-shaders::walk '(attribute ,name ,type ,@args)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro glsl-input (name type &rest args &key  stage location)
  (declare (ignore location))
  `(with-package-environment ()
     (3bgl-shaders::walk '(input ,name ,type ,@args)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro glsl-output (name type &rest args &key stage location)
  (declare (ignore location))
  `(with-package-environment ()
     (3bgl-shaders::walk '(output ,name ,type ,@args)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro glsl-uniform (name type &rest args &key  stage location)
  (declare (ignore location stage))
  `(with-package-environment ()
     (3bgl-shaders::walk '(uniform ,name ,type ,@args)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro glsl-bind-interface (stage block-name interface-qualifier instance-name)
  `(with-package-environment ()
     (3bgl-shaders::walk '(bind-interface ,stage ,block-name
                           ,interface-qualifier ,instance-name)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defun generate-stage (stage main)
 (let ((*package* (or (symbol-package main) *package*)))
   (nth-value 4
              (glsl::with-package-environment()
                (3bgl-shaders::compile-block nil main stage
                                             :env 3bgl-shaders::*environment*
                                             :print-as-main main)))))


;;; CL macros for the glsl API (for use with slime when working on files
;;;  to be loaded as glsl code)

(cl:defmacro defun (name args &body body)
  `(with-package-environment ()
     (3bgl-shaders::walk '(cl:defun ,name ,args ,@body)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro defconstant (name value type)
  `(with-package-environment ()
     (3bgl-shaders::walk '(%defconstant ,name ,value ,type)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro interface (name (&rest args &key in out uniform) &body slots)
  (declare (ignore in out uniform))
  `(with-package-environment ()
     (3bgl-shaders::walk '(interface ,name ,args ,@slots)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro attribute (name type &rest args &key location)
  (declare (ignore location))
  `(with-package-environment ()
     (3bgl-shaders::walk '(attribute ,name ,type ,@args)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro input (name type &rest args &key  stage location)
  (declare (ignore location))
  `(with-package-environment ()
     (3bgl-shaders::walk '(input ,name ,type ,@args)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro output (name type &rest args &key stage location)
  (declare (ignore location))
  `(with-package-environment ()
     (3bgl-shaders::walk '(output ,name ,type ,@args)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro uniform (name type &rest args &key  stage location)
  (declare (ignore location stage))
  `(with-package-environment ()
     (3bgl-shaders::walk '(uniform ,name ,type ,@args)
                         (make-instance '3bgl-shaders::extract-functions))))

(cl:defmacro bind-interface (stage block-name interface-qualifier instance-name)
  `(with-package-environment ()
     (3bgl-shaders::walk '(bind-interface ,stage ,block-name
                           ,interface-qualifier ,instance-name)
                         (make-instance '3bgl-shaders::extract-functions))))
