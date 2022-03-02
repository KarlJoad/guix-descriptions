(use-modules (gnu home)
             (gnu home services)
             (gnu home services shells)
             (gnu home services shepherd)
             (gnu services)
             (gnu packages admin)
             (gnu packages password-utils)
             (gnu packages emacs)
             (gnu packages engineering)
             (guix gexp))

(define (emacs-server server-name)
  (define (server-name->symbol server-name)
    (let ((emacs-server-symbol 'emacs-server))
      (if (string-null? server-name)
          emacs-server-symbol
          (symbol-append emacs-server-symbol (string->symbol "-")
                         (string->symbol server-name)))))
  (define (server-name->server-socket-name server-name)
    (if (string-null? server-name) "server" server-name))

  (shepherd-service
   (provision (list
               (server-name->symbol server-name)));; (server-name-suffix server-name))))
   (requirement '())
   (respawn? #t)
   (start #~(make-forkexec-constructor
             (list #$(file-append emacs "/bin/emacs")
                   #$(format #f "--fg-daemon=~a"
                             (server-name->server-socket-name server-name)))
             #:log-file (string-append
				                 (or (getenv "XDG_LOG_HOME")
				                     (format #f "~a/.local/var/log"
					                           (getenv "HOME")))
				                 #$(format #f "/emacs-~a.log"
                                   (server-name->server-socket-name server-name)))))
   (stop ;; #~(make-kill-destructor)
         #~(make-system-destructor
            #$(file-append emacs "/bin/emacsclient" " "
                           (format #f "--socket-name=~a"
                                   (server-name->server-socket-name server-name))
                                 " " "--eval '(kill-emacs)'"))
         )
   (documentation (string-append "Emacs server"
                                 (if (string-null? server-name)
                                     ""
                                     (string-append " for " server-name))))))

(home-environment
 (packages
  (list password-store ;; pass
        lepton-eda
        ))
 (services
  (list
   (service home-bash-service-type
            (home-bash-configuration
             (guix-defaults? #t)
             (aliases
              '(("grep='grep --color'" . "auto")
                  ("ll" . "'ls -la'")
                  ("ls='ls -p --color'" . "auto")))
             (bashrc
              (list (local-file "bashrc" "bashrc")))
             (bash-profile
                (list (local-file "bash_profile" "bash_profile")))))
   (service home-shepherd-service-type
            (home-shepherd-configuration
             (auto-start? #t)
             (services
              (list
               (emacs-server "")
               (emacs-server "debug")))))
   )))
