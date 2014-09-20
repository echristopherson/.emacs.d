;;;; -*- lexical-binding: t -*-

;; TODO: Prefix my functions with something like eac-

;; TODO: Figure out most economical way to affect all Lisp modes,
;;       e.g. in hooks.

;; TODO: Figure out whether to consistently use autoload or
;;       not. (Package management means autoload is automatic for
;;       packages, at least.)

;; Globals for broad preferences; set these and reload init.el to
;; change behavior fairly easily.
;; TODO: Make these reversible.
(defvar *use-evil?* nil "Whether or not to load and enable evil mode.")
(defvar *use-xiki?* nil "Whether or not to load and enable el4r (for Xiki)")
(defvar *use-paredit?* t "Whether or not to load and enable paredit and electric Return")
(defvar *enable-slime?* t "Whether to enable SLIME (by loading required packages and configuring certain things")
(defvar *enable-cider?* t "Whether to enable Cider (by loading required packages and configuring certain things")

;;;;;;;;;;;;
;; el-get ;;
;;;;;;;;;;;;

(add-to-list 'load-path "~/.emacs.d/el-get/el-get")

(unless (require 'el-get nil t)
  (url-retrieve
   "https://github.com/dimitri/el-get/raw/master/el-get-install.el"
   (lambda (s)
     (end-of-buffer)
     (eval-print-last-sexp))))

;; now either el-get is `require'd already, or have been `load'ed by the
;; el-get installer.

(setf my:elpa-packages '(
                         auto-complete
                         evil
                         evil-surround
                         exec-path-from-shell
                         ;; ir_black-theme ; I used to have this shown in list-packages; but I'm pretty sure it was always actually local.
                         magit
                         paredit
                         popup ; this should be pulled in by auto-complete, but fsr isn't right now
                         pos-tip
                         undo-tree
                         ))

(cond (*enable-slime?*
       (setf my:elpa-packages (append my:elpa-packages
                                      '(
                                        ac-slime
                                        ;; slime ; for now at least I'm keeping this in Quicklisp
                                        )))))
(cond (*enable-cider?*
       (setf my:elpa-packages (append my:elpa-packages
                                      '(
                                        ac-cider
                                        cider
                                        )))))

;; set local recipes, el-get-sources should only accept PLIST element
(setq el-get-sources (mapcar (lambda (elpa-package)
                               `(:name ,elpa-package :type elpa))
                             my:elpa-packages))

;; now set our own packages
(setq
 my:el-get-packages
 '(el-get                               ; el-get is self-hosting
   ))

(setq my:el-get-packages
      (append my:el-get-packages
              (mapcar #'el-get-source-name el-get-sources)))

;; install new packages and init already installed packages
(el-get 'sync my:el-get-packages)

;;;;;;;;;;;;;;;
;; undo-tree ;;
;;;;;;;;;;;;;;;

;; TODO: enabling persistent history makes Emacs slow to start up. An
;; old note that was here said it used 40% of Emacs's startup
;; time. Try to make it faster.
(global-undo-tree-mode)
(setf undo-tree-auto-save-history t)
(make-directory "~/.emacs.d/undo" t)
(add-to-list 'undo-tree-history-directory-alist
             '(".*" . "~/.emacs.d/undo"))

;;;;;;;;;;
;; evil ;;
;;;;;;;;;;

(when *use-evil?*
  ;; Enable evil mode
  (evil-mode 1)

  ;; Add `:enew` command to Evil
  (evil-define-command evil-buffer-new ()
                       "Opens a new buffer in the current window."
                       :repeat nil
                       (let ((buffer (generate-new-buffer "*new*")))
                         (set-window-buffer (selected-window) buffer)
                         (with-current-buffer buffer
                           (evil-normal-state))))

  (evil-ex-define-cmd "enew" 'evil-buffer-new)

  ;; evil surround
  ;; TODO: depends on something I haven't found in packages
  (global-evil-surround-mode 1))

;;;;;;;;;
;; org ;;
;;;;;;;;;

(add-to-list 'auto-mode-alist '("\\.org\\'" . org-mode))
(global-set-key "\C-cl" 'org-store-link)
(global-set-key "\C-cc" 'org-capture)
(global-set-key "\C-ca" 'org-agenda)
(global-set-key "\C-cb" 'org-iswitchb)

;;;;;;;;;;
;; Lisp ;;
;;;;;;;;;;

(defvar *lisp-mode-hooks*
  '(emacs-lisp-mode-hook
    lisp-mode-hook
    lisp-interaction-mode-hook
    scheme-mode-hook
    clojure-mode-hook
    )
  "List of Lisp modes to add hooks to.")

(when *enable-slime?*
  (setf *lisp-mode-hooks* (append *lisp-mode-hooks*
                                  '(
                                    slime-repl-mode-hook
                                    ))))
(when *enable-cider?*
  (setf *lisp-mode-hooks* (append *lisp-mode-hooks*
                                  '(
                                    cider-repl-mode-hook
                                    ))))

;; TODO: elisp mode now doesn't evaluate and print when C-j is pressed; C-u C-x C-e works. Find a way to make C-j work again.

;; Auto indent when RET is pressed (not just C-j)
(defun use-newline-and-indent ()
  (local-set-key (kbd "RET") 'newline-and-indent))

(mapcar #'(lambda (hook)
            (unless (eq hook 'cider-repl-mode-hook) ; TODO: horrible kludge to make RET work in Clojure REPL
              (remove-hook hook #'use-paredit-electrify-return-if-match)
              (add-hook hook #'use-newline-and-indent)))
        *lisp-mode-hooks*)

;; SLIME
(cond (*enable-slime?* 
       (add-to-list 'load-path "~/.quicklisp/dists/quicklisp/software/slime-2.9")
       (setq inferior-lisp-program "/usr/local/bin/sbcl") ; your Lisp system
       (require 'slime-autoloads)
       (slime-setup '(slime-fancy))     ; load contrib packages

       ;; Point SLIME to copy of HyperSpec installed locally.
       (setq common-lisp-hyperspec-root
             "/usr/local/share/doc/hyperspec/HyperSpec/")
       (setq common-lisp-hyperspec-symbol-table
             (concat common-lisp-hyperspec-root "Data/Map_Sym.txt"))
       (setq common-lisp-hyperspec-issuex-table
             (concat common-lisp-hyperspec-root "Data/Map_IssX.txt"))

       ;; Use C-c C-] to close all parens in SLIME REPL, just like in Lisp mode.
       (add-hook 'slime-repl-mode-hook
                 #'(lambda ()
                     (local-set-key (kbd "C-c C-]") 'slime-close-all-parens-in-sexp)))
       ;; This won't work, because slime hasn't been loaded yet:
       ;; (define-key slime-repl-mode-map (kbd "C-c C-]") 'slime-close-all-parens-in-sexp)

       ;; Show parenthesis matching the one under the cursor
       (show-paren-mode +1)

       ;; Start SLIME and position frame and windows the way I like
       (defun my-slime (&optional lisp-command)
         (interactive)
         ;; Position and size window if using GUI
         (when (display-graphic-p)
           (let ((frame (selected-frame)))
             (set-frame-position frame 63 487)
             (set-frame-size frame 168 22)))
         ;; Split window into two side by side windows
         (split-window-horizontally)
         ;; Launch SLIME. Use `lisp-command' argument, if supplied; otherwise
         ;; just go with `slime''s default (which currently is the global
         ;; `inferior-lisp-program', but we shouldn't depend on that.
         (if lisp-command
             (slime lisp-command)
           (slime))
         ;; Choose desired directory both in Emacs in general and the REPL
         ;; TODO: Use regular let once I've upgraded to Emacs 24 (which has
         ;; optional lexical binding; the comment at the beginning of this
         ;; file enables it).
         (lexical-let ((lisp-directory "~/Code/learning/practical_common_lisp"))
           ;; This needs to be a hook because otherwise Emacs will try to
           ;; execute it before SLIME has finished loading.  TODO: We should
           ;; probably not make this a hook; instead, change directories
           ;; before calling slime and then reset afterwards.
           (add-hook 'slime-connected-hook
                     #'(lambda ()
                         (cd lisp-directory)
                         (slime-cd lisp-directory)))))

       ;; jsj-ac-show-help by Scott Jaderholm -- pop up help on Lisp
       ;; functions w/ C-c C-h. Requires SLIME.
       ;; TODO: test this, once SLIME is working again.
       (defun jsj-ac-show-help ()
         "show docs for symbol at point or at beginning of list if not on a symbol"
         (interactive)
         (let ((s (save-excursion
                    (or (symbol-at-point)
                        (progn (backward-up-list)
                               (forward-char)
                               (symbol-at-point))))))
           (pos-tip-show (or (if (equal major-mode 'emacs-lisp-mode)
                                 (ac-symbol-documentation s)
                               (ac-slime-documentation (symbol-name s))) "no docs")
                         'popup-tip-face
                         ;; 'alt-tooltip
                         (point)
                         nil
                         -1)))
       ))

;; This mapping is also usable in elisp mode. I guess
;; lisp-mode-shared-map must be shared by several Lisp modes.
(define-key lisp-mode-shared-map (kbd "C-c C-h") 'jsj-ac-show-help)

;;;;;;;;;;;;;;;;;;;
;; auto-complete ;;
;;;;;;;;;;;;;;;;;;;

;; auto-complete
;; Set up useful defaults for different modes
(ac-config-default)

;; ac-slime
;; TODO: test this, once SLIME is working again.
(cond (*enable-slime?*
       (add-hook 'slime-mode-hook #'set-up-slime-ac)
       (add-hook 'slime-repl-mode-hook #'set-up-slime-ac)
       (eval-after-load "auto-complete"
         '(add-to-list 'ac-modes 'slime-repl-mode))
       ))

;;;;;;;;;;;;;
;; paredit ;;
;;;;;;;;;;;;;

;; Not sure I want to use this full-time yet. The stable version seems
;; to do unexpected things, and often wrongly thinks parens are
;; unbalanced.
(when *use-paredit?*
  (autoload 'paredit-mode "paredit"
    "Minor mode for pseudo-structurally editing Lisp code." t)
  (mapcar #'(lambda (hook)
              (add-hook hook
                        #'(lambda ()
                            (paredit-mode +1))))
          *lisp-mode-hooks*)

  ;; Special treatment is advised with SLIME: "SLIME’s REPL has the
  ;; very annoying habit of grabbing DEL which interferes with
  ;; paredit’s normal operation. To alleviate this problem use the
  ;; following code: Stop SLIME's REPL from grabbing DEL, which is
  ;; annoying when backspacing over a '('
  (cond (*enable-slime?*
         (add-hook 'slime-repl-mode-hook 
                   #'(lambda ()
                       (define-key slime-repl-mode-map
                         (read-kbd-macro paredit-backward-delete-key) nil))
                   t ; append to hook list, so it runs after (paredit-mode +1)
                   )
         ))

  ;; Electric Return
  (defvar *paredit-electrify-return-match*
    "[\]}\)\"]"
    "If this regexp matches the text after the cursor, do an \"electric\"
  return.")
  (defun paredit-electrify-return-if-match (arg)
    "If the text after the cursor matches `*paredit-electrify-return-match*' then
  open and indent an empty line between the cursor and the text.  Move the
  cursor to the new line."
    (interactive "P")
    (let ((case-fold-search nil))
      (when (looking-at *paredit-electrify-return-match*)
        (save-excursion (newline-and-indent)))
      (newline arg)
      (indent-according-to-mode)))
  (defun use-paredit-electrify-return-if-match ()
    (local-set-key (kbd "RET") 'paredit-electrify-return-if-match))
  (mapcar #'(lambda (hook)
              (unless (eq hook 'cider-repl-mode-hook) ; TODO: horrible kludge to make RET work in Clojure REPL
                (remove-hook hook #'use-newline-and-indent)
                (add-hook hook #'use-paredit-electrify-return-if-match)))
          *lisp-mode-hooks*))

;;;;;;;;;;;;;;;;;;;;;
;; Xiki (via el4r) ;;
;;;;;;;;;;;;;;;;;;;;;

(when *use-xiki?*
  ;; Beginning of the el4r block:
  ;; RCtool generated this block automatically. DO NOT MODIFY this block!
  (add-to-list 'load-path "/Users/eric/.rvm/rubies/ruby-1.9.3-p194/share/emacs/site-lisp")
  (require 'el4r)
  (el4r-boot)
  ;; End of the el4r block.
  ;; User-setting area is below this line.
  )

;;;;;;;;;;
;; howm ;;
;;;;;;;;;;

;; TODO: Make this work on OS X. howm is actually installed in the
;; Homebrew Cocoa Emacs 24, but Emacs can't seem to load it fsr. It
;; does load in the prepackaged 23.
;; (require 'howm)
;; (howm-mode)

;;;;;;;;;;;;
;; custom ;;
;;;;;;;;;;;;

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes (quote ("27b53b2085c977a8919f25a3a76e013ef443362d887d52eaa7121e6f92434972" default)))
 '(face-font-family-alternatives (quote (("Menlo" "Liberation Mono" "DejaVu Sans Mono") ("Monospace" "courier" "fixed") ("courier" "CMU Typewriter Text" "fixed") ("Sans Serif" "helv" "helvetica" "arial" "fixed") ("helv" "helvetica" "arial" "fixed"))))
 '(safe-local-variable-values (quote ((lexical-binding . t))))
 '(scroll-bar-mode nil)
 '(tool-bar-mode nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:inherit nil :stipple nil :inverse-video nil :box nil :strike-through nil :overline nil :underline nil :slant normal :weight normal :height 110 :width normal :foundry "monotype" :family "Menlo")))))

;;;;;;;;;;;;;;;;
;; Appearance ;;
;;;;;;;;;;;;;;;;

;; Color theme
(if (< emacs-major-version 24)
    ;; color-theme only works on <= 23
    (progn
      (add-to-list 'load-path "~/.emacs.d/color-theme")
      (require 'color-theme)
      (eval-after-load "color-theme"
        '(progn
                                        ;(color-theme-initialize)
                                        ;(load-file "~/.emacs.d/color-theme/color-theme-irblack.el")
                                        ;(color-theme-irblack))))
           ;; Slightly different version of ir_black:
                                        ;(load-file "~/.emacs.d/color-theme/color-theme-ir-black.el")
                                        ;(color-theme-ir-black))))
           ;; My derivative of ir_black:
           (load-file "~/.emacs.d/color-theme/color-theme-ir-gray_EAC.el")
           (color-theme-ir-gray_EAC))))
  ;; Emacs >= 24 has its own built-in theming functionality
  (add-to-list 'custom-theme-load-path "~/.emacs.d/themes")
  (load-theme 'ir-gray_EAC t))

;; Cursor: don't blink
(blink-cursor-mode 0)

;; Hide menu bar in terminal
(unless (display-graphic-p)
  (menu-bar-mode -1))

;; Don't show splash screen
(setq inhibit-startup-screen t)

;; TODO: Show trailing whitespace as gray middle dots.

;;;;;;;;;;;;;;;;;;;
;; Miscellaneous ;;
;;;;;;;;;;;;;;;;;;;

;; Add a dir for my own scripts to load path
(add-to-list 'load-path "~/.emacs.d/lisp")

;; Directory to look in for Emacs C source
(setf source-directory "~/Code/others/emacs/emacs--bzr")

;; Don't use any tabs in indentation (Emacs by default changes 8 spaces to
;; tab)
;; C-q <tab> inserts one anyway (like C-v <tab> in Vim).
(setq-default indent-tabs-mode nil)

;; Do away with necessity to type `yes' or `no' instead of simple `y' and `n'
(defun yes-or-no-p (&rest args)
  (apply #'y-or-n-p args))

;; If running in a terminal, use elinks in tmux to open URLs with
;; `browse-url' and `hyperspec-lookup'.
;; TODO: Detect tmux; if it's not running, use default browser.
(unless (display-graphic-p)
  (defvar my-browse-url-elinks-browser "elinks")
  (defvar my-browse-url-tmux-program "tmux")
  (defvar my-browse-url-tmux-args '("split-window" "-h"))

  ;; Adapted from browse-url-text-xterm in browse-url.el
  (defun my-browse-url-tmux-elinks (url &optional new-window)
    ;; new-window ignored (for now)
    "Ask tmux to create a new split to the right, in which elinks
will be run to load URL. URL defaults to the URL around or before
point."
    (interactive (browse-url-interactive-arg "Text browser URL: "))
    (apply #'start-process
           `(,(concat my-browse-url-elinks-browser url)
             nil
             ,my-browse-url-tmux-program
             ,@my-browse-url-tmux-args
             ,(mapconcat 'identity (list my-browse-url-elinks-browser url) " "))))

  (setf browse-url-browser-function #'my-browse-url-tmux-elinks)

  (global-set-key (kbd "<f11>") 'my-toggle-use-option-for-input-method))

;; Stop bell from ringing when I press C-g in the minibuffer or
;; during isearch.
(setq ring-bell-function
      (lambda ()
        (unless (memq this-command '(isearch-abort
                                     isearch-done abort-recursive-edit
                                     exit-minibuffer keyboard-quit))
          (ding))))

;; Use visible instead of audible bell.
                                        ;(setq visible-bell 1)

;; Adjust path
;; This helps Emacs find executables to run, e.g. emacsclient in
;; magit (which must be the /usr/local/bin version).
;; Apps in OS X >= 10.8 can't load path or other variables from
;; ~/.MacOSX/environment.plist
(exec-path-from-shell-initialize)

;; Show certain buffer on startup when no files have been
;; specified. A value of t makes Emacs show *scratch* (which is the
;; default if the splash screen is disabled).
                                        ;(setq initial-buffer-choice "some_file")

;; Use gls for ls (since it supports --dired)
;; TODO: Autodetect whether running on Linux or OS X and set accordingly.
(setq insert-directory-program "gls")

;; Hide dot files in dired
;; Use M-o to toggle hiding.
(require 'dired-x)
(setq-default dired-omit-files-p t)
(setq dired-omit-files (concat dired-omit-files "\\|^\\..+$"))

;; Backup directory instead of *~ files
;; From <http://emacswiki.org/emacs/BackupDirectory> and <http://snarfed.org/gnu_emacs_backup_files>
(make-directory "~/.emacs.d/backup" t)
(setq
 backup-by-copying t              ; don't clobber symlinks
 backup-directory-alist
 '(("." . "~/.emacs.d/backup"))    ; don't litter my fs tree
 delete-old-versions t
 kept-new-versions 6
 kept-old-versions 2
 version-control t                ; use versioned backups
 )

;;;;;;;;;;;;;;;;;;
;; Key bindings ;;
;;;;;;;;;;;;;;;;;;

;; Jump to definition of elisp function
(global-set-key (kbd "C-h C-f") 'find-function)

;; TODO: This is for historical reference only. I use BTT now for middle
;; button.
;; C-M-mouse-1 as mouse-2
;; Doesn't quite work right yet in some cases.
;; From FreeNode #emacs:
;; <echristopherson> I bound (with key-translation-map) M-C-mouse-1 to mouse-2 in GNU
;; Emacs.app (for OS X), but when I use M-C-mouse-1, I get the message
;; "mouse-yank-at-click must be bound to an event with parameter". Is that
;; what normally happens when you click mouse-2 in an editing area, or is
;; there something wrong with my mapping?
;; ...
;; <echristopherson> Is it normal for a mouse-2 click on some text to show the message
;; "mouse-yank-at-click must be bound to an event with parameter"?
;; ...
;; <tali713> yes, that error indicates that somehow mouse-2 is bond oddly in
;; your given context.
;; <tali713> s/bond/bound/
;; ...
;; <tali713> echristopherson: you don't have a three button mouse?  what OS?
;; ...
;; <echristopherson> os x
;; <tali713> echristopherson: look in to better touch tool
;; ...
;; <tali713> echristopherson: it will allow you to simulate a three button mouse.
;; ...
;; <tali713> echristopherson: use, as with all mac applications.
;; (define-key key-translation-map (kbd "<C-M-down-mouse-1>") (kbd "<down-mouse-2>"))
;; (define-key key-translation-map (kbd "<C-M-up-mouse-1>") (kbd "<up-mouse-2>"))
;; (define-key key-translation-map (kbd "<C-M-mouse-1>") (kbd "<mouse-2>"))

;; Cmd+Return for full screen; requires patch to Cocoa Emacs
;; TODO: Why doesn't `s-RET' work here?
(global-set-key (kbd "<s-return>") 'toggle-frame-fullscreen)

;; C-c SPC to move right, potentially past the end of a
;; line. Useful for rectangular selection. Unlike in my Vim setup,
;; this does insert spaces if you go past the current EOL.
;; Note that C-c SPC is used by shell mode and ace-jump mode; and C-c
;; C-SPC is used by ERC.
;; picture.el must be loaded first.
(require 'picture)
(global-set-key (kbd "C-c SPC") 'picture-forward-column)

;; my-describe-function -- from
;; <http://www.emacswiki.org/emacs/PosTip> -- works like
;; jsj-ac-show-help above sort of
;; TODO: test this, once SLIME is working again.
;; TODO: Actually, this doesn't seem to be SLIME-specific; but I can't
;; get it working now in elisp mode.
(require 'pos-tip)
(defun my-describe-function (function)
  "Display the full documentation of FUNCTION (a symbol) in tooltip."
  (interactive (list (function-called-at-point)))
  (if (null function)
      (pos-tip-show
       "** You didn't specify a function! **" '("red"))
    (pos-tip-show
     (with-temp-buffer
       (let ((standard-output (current-buffer))
             (help-xref-following t))
         (prin1 function)
         (princ " is ")
         (describe-function-1 function)
         (buffer-string)))
     nil nil nil 0)))

;; TODO: I'm not sure this is necessary. It seems to work with C-c C-h
;; too.  Actually, in elisp buffers at least, C-c C-h seems to
;; describe the word under or before point; C-; at least sometimes
;; describes the word at the start of the form.
(define-key emacs-lisp-mode-map (kbd "C-;") 'my-describe-function)

;; In Cocoa Emacs, use F11 (chosen because it was what I had already
;; arbitrarily chosen for that purpose in MacVim) to toggle behavior
;; of Option and Command keys.
;; NOTE: iTerm2 profiles allow the behavior of left Option and right Option
;; be different.
(when (display-graphic-p)
  (when (equal window-system 'ns)
    (defun my-use-option-for-input-method ()
      (setf mac-option-modifier nil
            mac-command-modifier 'meta))

    (defun my-use-option-for-meta ()
      (setf mac-option-modifier 'meta
            mac-command-modifier 'super))

    (defun my-toggle-use-option-for-input-method ()
      "Toggle between (1) using Option for meta and Command for super and (2) passing Option through to OS X and using Command for meta. If neither one of these configurations is active, the first is chosen."
      (interactive)
      (if (and (equal mac-option-modifier 'meta)
               (equal mac-command-modifier 'super))
          (setf mac-option-modifier nil
                mac-command-modifier 'meta)
        (setf mac-option-modifier 'meta
              mac-command-modifier 'super)))))
