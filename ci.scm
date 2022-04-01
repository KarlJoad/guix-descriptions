;; (use-modules (synnax))
(use-service-modules networking ssh web cuirass)
(use-package-modules bootloaders ssh version-control certs)

;; NOTE: If using SSH-protected channels, MUST have nss-certs in globally
;; available packages!
(define %cuirass-specification
  #~(list (specification
           (name "test-guix-hello-timer")
           (build 'hello)
           ;; How frequently to attempt to build this specification, in seconds
           (period (* 10 60)))
          (specification
           (name "personal")
           (channels (list (channel
                            (name 'synnax)
                            (url "https://github.com/KarlJoad/synnax.git"))
                           (channel (inherit %default-guix-channel))))
           (build '(channels synnax))
           (period 0))
          (specification
           (name "nonguix")
           (channels (list
                      (channel
                       (name 'nonguix)
                       (url "https://gitlab.com/nonguix/nonguix"))
                      (channel (inherit %default-guix-channel))))
           (build '(channels nonguix)))
    ))

(define %system
  (operating-system
   (host-name "Karl-CI")
   (timezone "America/Chicago")
   (bootloader
    (bootloader-configuration
     (bootloader grub-bootloader)
     (targets (list "/dev/sda"))
     (keyboard-layout (keyboard-layout "us"))
     (terminal-outputs '(console))))
   (swap-devices
    (list (swap-space
           (target
            (uuid "dacd0179-d888-47d4-a910-ac58ae14fac3")))))
   (file-systems
    (cons* (file-system
            (mount-point "/")
            (device
             (uuid "9f14407e-8cb3-4b09-b2c3-3363340fafdd"
                   'ext4))
            (type "ext4"))
           %base-file-systems))
   (packages
    (append (list git
                  nss-certs)
            %base-packages))
   (services
    (append (list (service dhcp-client-service-type)
                  (service openssh-service-type
                           (openssh-configuration
                            (openssh openssh-sans-x)
                            (password-authentication? #false)
                            (permit-root-login #t)
                            (log-level 'debug)
                            (authorized-keys
                             ;; Authorise our SSH key.
                             ;; SSH access must be able to access/elevate to user in config list at bottom
                             `(("root" ,(local-file "./ci_rsa.pub"))))))
                  (service cuirass-service-type
                           (cuirass-configuration
                            (specifications %cuirass-specification)
                            ;; How frequently to fetch spec's channels, in seconds
                            (interval (* 1 60 60))
                            (host "0.0.0.0"))))
            (modify-services %base-services
                             (guix-service-type config =>
                                                (guix-configuration
                                                 (inherit config)
                                                 ;; (extra-options (list "--max-jobs" 4
                                                 ;;           "--cores" 4))
                                                 (authorized-keys
                                                  ;; Guix signing key generated by Guix in /etc/guix/
                                                  (append (list (local-file "./guix-coordinator.pub"))
                                                          %default-authorized-guix-keys)))))))))

(list (machine
       (operating-system %system)
       (environment managed-host-environment-type)
       (configuration (machine-ssh-configuration
           ;; IP or DNS-resolved address of machine(s) to manage
           (host-name "192.168.20.230")
           (system "x86_64-linux")
           ;; SSH host key of system being configured
           (host-key "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG2OIXsMCJ3SxJcQTZj4B7OVc2uD4K3bd56ST8GJyi1p root@(none)")
           (user "root")))))
