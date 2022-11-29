;; Copyright (c) 2021 Sebastian Glas

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

;;;; signed-http-ping.lisp

(in-package #:signed-http-ping)
;;
;; secure http ping
;;  monitor: use a http request with a shared secret
;;  to send /receive/ check alive-signal
;;
;; Assumptions: identical system time values in both systems; an identical shared secret; http & smtp port available
;;

(defvar *hashes* nil)
(vom:config t :info)
(defvar *log-file* "C:/tmp/signed-ping.log")  ;change to your needs 
(defvar *acceptor* nil)

(defun notify-mail (text)  ; in case of monitoring gaps, send a notification e-mail
  (handler-case 
      (trivial-timeout:with-timeout (60)
	(cl-smtp:send-email "smtp.your-isp.com" "your-robot-mailaccount@your-isp.com" "monitoring-alert@your-isp.com" text "Msg Body empty."
			    :authentication (list "your-robot-mailaccount@your-isp.com" "yourpassword")))
    (trivial-timeout:timeout-error (c) 
      (vom:warn "Mail Sending timeout (~A)~%" c))))

(defun stop-hunchentoot-server ()
  (when *acceptor*
    (hunchentoot:stop *acceptor*)))

(defun start-hunchentoot-server (port)
  (stop-hunchentoot-server)
  (hunchentoot:start (setf *acceptor*
			   (make-instance 'hunchentoot:easy-acceptor
					  :port port))))

(define-easy-handler (monitor :uri "/monitor") (hash)
  (vom:info "Transmitted hash: ~A.~%" hash)
  (vom:info "Number of hashes before: ~A~%" (length *hashes*))
  (vom:info "Current list of hashes: ~{~A~%~}" *hashes*)
  (if (member hash *hashes* :test #'string=)
      (setf *hashes* (remove hash *hashes* :test #'string=))  ;remove the hash, if a matching one was sent by client (=monitoring success)
      ;; else
      (vom:warn "Unknown hash. Invalid http-ping. ('~A')" hash))
  (vom:info "Number of hashes after: ~A." (length *hashes*)))


(defun start-signed-http-ping-server (port secret)
  "Listener Process."
  (format *terminal-io* "Starting signed http listener.~%")
  (start-hunchentoot-server port)
  (handler-case 
      (with-open-file
	  (log-stream *log-file*
		      :direction :output :if-exists :append :if-does-not-exist :create :external-format :latin1)
	(setf vom:*log-stream* log-stream)
	(vom:info "System started ~A." (local-time:format-timestring nil (local-time:now)) )
	(loop
	   (vom:info "Beginning new Monitoring Loop. Length of Hashes: ~A" (length *hashes*))
	   ;; every 5 minutes, renew hash-list. expect at least 3 successful requests = 4 removals from 10
	   ; initial start:
	   (vom:info "Comparison: 6 versus ~A" (length *hashes*))
	   (when (and *hashes* (< 6 (length *hashes*)))
	     (progn 
	       (vom:info "Notification condition. Sending Mail.")
	       (notify-mail (format nil "MONITORING: below min of 4 requests (Unprocessed Hashes: ~A)" (length *hashes*)))
	       (vom:warn "WARNING - Monitoring below threshold! Number of hashes: ~A" (length *hashes*))))
	   (setf *hashes* (loop for x in (make-time-window) collecting (make-check-string x secret)))
	   (vom:info "Sleeping initiated. Length of Hashes: ~A." (length *hashes*))
	   (vom:info "Current List of Hashes:~%~{~A~%~}" *hashes*)
	   (sleep 300)))
    (error (c) (format *terminal-io* "Error: ~A~%" c))))


(defun client-main (remote-host remote-port secret)
  "Contact a web server with this form http://localhost:8182/monitor?hash=..."
  (handler-case 
      (with-open-file
	  (log-stream *log-file*
		      :direction :output :if-exists :append :if-does-not-exist :create :external-format :latin1)
	(setf vom:*log-stream* log-stream)
	(vom:info "Monitoring Client started. Remote host '~A' port '~A'" remote-host remote-port)
	(loop
	   (handler-case
	       (let ((per-minute-hash (make-check-string (local-time:now) secret)))
		 (vom:info "Entering Client Loop. Hash: '~A'" per-minute-hash (local-time:now))
		 (drakma:http-request 
		  (format nil "http://~A:~A/monitor?hash=~A" remote-host remote-port per-minute-hash)
		  :method :get :connection-timeout :20)
		 (vom:info "Sleeping.")
		 (sleep 60))
	     (error (c) (vom:error "Error: ~A." c)))
	   )) ;loop
    (error (c) (format *terminal-io* "Error: ~A." c))
    ))
  
(defun make-check-string (timestamp secret)
  "Calculate and return time-based shared secret
   returns e.g. ''6737fb3707d3959f7018acabd14bd21e7934a787e9b94c0bf6b9531c21652ca7'' "
  (let ((digester (ironclad:make-digest :sha256)))
    (ironclad:byte-array-to-hex-string
     (ironclad:digest-sequence digester
			       (flexi-streams:string-to-octets 
				(format nil "~A~A~A~A~A~A"
					(local-time:timestamp-year timestamp)
					(local-time:timestamp-month timestamp)
					(local-time:timestamp-day timestamp)
					(local-time:timestamp-hour timestamp)
					(local-time:timestamp-minute timestamp)
					secret))))))


(defun make-time-window ()
  "create a list with 4 earlier, current and 5 later timestamps"
  (let ((now (local-time:now)))
    (list
     (local-time:timestamp- now 4 :minute)
     (local-time:timestamp- now 3 :minute)
     (local-time:timestamp- now 2 :minute)
     (local-time:timestamp- now 1 :minute)
     now
     (local-time:timestamp+ now 1 :minute)
     (local-time:timestamp+ now 2 :minute)
     (local-time:timestamp+ now 3 :minute)
     (local-time:timestamp+ now 4 :minute)
     (local-time:timestamp+ now 5 :minute))))
     
	
