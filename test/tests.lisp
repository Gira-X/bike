;;;; -*- Mode: lisp; indent-tabs-mode: nil -*-

;;; Copyright (C) 2019, Dmitry Ignatiev <lovesan.ru at gmail.com>

;;; Permission is hereby granted, free of charge, to any person
;;; obtaining a copy of this software and associated documentation
;;; files (the "Software"), to deal in the Software without
;;; restriction, including without limitation the rights to use, copy,
;;; modify, merge, publish, distribute, sublicense, and/or sell copies
;;; of the Software, and to permit persons to whom the Software is
;;; furnished to do so, subject to the following conditions:

;;; The above copyright notice and this permission notice shall be
;;; included in all copies or substantial portions of the Software.

;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;;; NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
;;; HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
;;; WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
;;; DEALINGS IN THE SOFTWARE.

(in-package #:cl-user)

(uiop:define-package #:bike-tests
  (:use #:cl #:bike #:fiveam)
  (:export #:bike-suite))

(in-package #:bike-tests)

(def-suite bike-suite
  :description "Tests")

(in-suite bike-suite)

(test test-hello
  (is (eq nil (invoke 'System.Console 'WriteLine "Hello, World!"))))

(test box-unbox-int
  (is (eql 4 (unbox (box 4 'int)))))

(test box-unbox-lisp-object
  (let ((object (make-instance 'standard-object)))
    (is (eq object (unbox (box object))))))

(test test-datetime-roundtrip
  (let* ((culture (property 'System.Globalization.CultureInfo 'InvariantCulture))
         (dt (property 'System.DateTime 'Now))
         (str (invoke dt 'ToString "o" culture)))
    (is (invoke :object 'Equals
                dt
                (invoke 'System.DateTime 'ParseExact str "o" culture)))))

(test test-vector-roundtrip
  (let* ((list (loop :for i :from 1 :to 10 :collect i))
         (vector (list-to-bike-vector list :element-type 'System.Int32)))
    (dotimes (i (property vector 'Length))
      (incf (dnvref vector i)))
    (is (= 65 (reduce #'+ (bike-vector-to-list vector))))))

(test test-exception
  (let ((ex nil))
    (handler-case
        (dnvref (new '(:array int) 0) 1)
      (dotnet-error (e)
        (setf ex (dotnet-error-object e))))
    (let ((type-name (and ex (property (invoke ex 'GetType)
                                       'FullName))))
      (is (equal "System.IndexOutOfRangeException" type-name)
          "Wrong exception type. Got: ~a" type-name))))

(test test-indexer
  (let ((dict (new '(System.Collections.Generic.Dictionary :string :string))))
    (setf (ref dict "Hello") "World")
    (is (string= "World" (ref dict "Hello")))))

(test test-read-only-indexer
  (let* ((boxed-string (box "Hello"))
         (ex (nth-value 1 (ignore-errors
                           (setf (ref boxed-string 0) #\A)))))
    (is (typep ex 'accessor-resolution-error))))

(test test-callback
  (let* ((x 1)
         (delegate (new 'System.Action (lambda () (incf x)))))
    (invoke delegate 'invoke)
    (is (= x 2))))

(test test-enumerable
  (let ((list (new '(System.Collections.Generic.List :int)))
        (sum 0))
    (dotimes (i 10)
      (invoke list 'Add i))
    (do-enumerable (x list)
      (incf sum x))
    (is (= sum 45))))

(test test-exception-bind
  (is-true (block ex-block
             (exception-bind ((System.IndexOutOfRangeException
                               (lambda (e)
                                 (declare (ignore e))
                                 (return-from ex-block t))))
               (progn (ref (box "") 0) nil)))))

(test test-exception-bind-restart
  (is-true (exception-bind ((System.IndexOutOfRangeException
                             (lambda (e)
                               (declare (ignore e))
                               (invoke-restart 'return-t))))
             (restart-case
                 (progn (ref (box "") 0) nil)
               (return-t () t)))))

(test test-exception-case
  (is-true
   (exception-case (progn (ref (box "") 0) nil)
     (System.IndexOutOfRangeException () t)
     (System.Exception () nil))))

(test test-exception-case-no-exception
  (is (eql 6 (exception-case (values 1 2 3)
               (System.Exception () nil)
               (:no-exception (a b c) (+ a b c))))))

(test test-disposable
  (let ((reader (new 'System.IO.StringReader "Hello, World!"))
        (got-ex nil))
    (with-disposable (r reader)
      (declare (ignore r)))
    (exception-case (invoke reader 'ReadToEnd)
      (System.ObjectDisposedException () (setf got-ex t)))
    (is-true got-ex)))

;;; vim: ft=lisp et
