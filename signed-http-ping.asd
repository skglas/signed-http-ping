;; Copyright (c) 2019-2022 Sebastian Glas

;; This software is provided 'as-is', without any express or implied
;; warranty. In no event will the authors be held liable for any damages
;; arising from the use of this software.

;; Permission is granted to anyone to use this software for any purpose,
;; including commercial applications, and to alter it and redistribute it
;; freely, subject to the following restrictions:

;; 1. The origin of this software must not be misrepresented; you must not
;;    claim that you wrote the original software. If you use this software
;;    in a product, an acknowledgment in the product documentation would be
;;    appreciated but is not required.
;; 2. Altered source versions must be plainly marked as such, and must not be
;;    misrepresented as being the original software.
;; 3. This notice may not be removed or altered from any source distribution.

;;;; signed-http-ping.asd

(asdf:defsystem #:signed-http-ping
  :description "Simple http-based client-server-monitoring loop with a shared secret"
  :author "Sebastian K Glas"
  :license  "ZLib"
  :version "0.0.1"
  :serial t
  :components ((:file "package")
               (:file "signed-http-ping"))
  :depends-on (:hunchentoot
	       :drakma
	       :local-time
	       :cl-smtp
	       :vom
	       :trivial-timeout
	       :flexi-streams
	       :ironclad)  )
