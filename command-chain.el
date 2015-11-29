;;; Word Chain game by emacs command names.

(require 'widget)

;; Is this needed?
(eval-when-compile
  (require 'wid-edit))

;; Configurable Variables

(defvar command-chain-player-count nil "Number of players.")
(defvar command-chain-players nil
  "Hash tables cotaining players' status.

Keys (must be symbols) and values are following:
  name : player's name (string)

This variables shold be accessed not directly but via functions
`command-chain-player-set' and `command-chain-player-get'
for future implementation change.")

;; Utilities

(defun command-chain-player-set (n key value)
  "Set KEY of N th player in `command-chain-players' to VALUE."
  (let ((player (aref command-chain-players n)))
    (puthash key value player)))

(defun command-chain-player-get (n key)
  "Get a value associated with KEY for N th player in `command-chain-players'."
  (let ((player (aref command-chain-players n)))
    (gethash key player)))

(defun command-chain--put-property (prop value s)
  ;; Put text propery to whole the S.
  (put-text-property 0 (length s) prop value s))

;; Definitions for config buffer

(defun command-chain-config-initialize-variables ()
  "Set configurable variables' initial values."
  (setq command-chain-players (make-vector command-chain-player-count nil))
  (dotimes (n command-chain-player-count)
    (let ((player (aset command-chain-players n (make-hash-table :test 'eq))))
      (puthash 'name (concat "Player " (number-to-string (1+ n))) player))))

(defun command-chain-config-create-player-widgets (player-n)
  "Create widgets to configure PLAYER-N th players's information."
  (widget-insert (concat "Player " (number-to-string (1+ player-n)) ":\n"))
  (widget-create 'editable-field
                 :size 12
                 :format (concat "    Name: %v\n")
                 :notify (lambda (widget &rest ignore)
                           (command-chain-player-set
                            player-n 'name (widget-value widget)))
                 (command-chain-player-get player-n 'name))
  (widget-insert "\n"))

;;; c.f. Info widget
(defun command-chain-config ()
  "Create config buffer."
  (interactive)
  (switch-to-buffer (generate-new-buffer "*Command Chain Config*"))
  (kill-all-local-variables)
  (command-chain-config-initialize-variables)

  (widget-insert "*** Game Config ***\n\n")
  (dotimes (i command-chain-player-count)
    (command-chain-config-create-player-widgets i))
  (widget-create 'push-button
                 :notify (lambda (&rest ignore)
                           (kill-buffer)
                           (command-chain-start-game))
                 "Start Game")
  (use-local-map widget-keymap)
  (widget-setup))

;; Game Variables

(defvar command-chain-current-player 0
  "Number representing whose turn the game is.")
(defvar command-chain-point-after-prompt 0
  "Point after prompt. Buffer content before this point must not be changed.")
(defvar command-chain-editing nil
  "Boolean indicating if buffer will be changed by private functions.
If non-nil, hooks for player's buffer editting get disabled.")

;; Game Utilities

(defmacro command-chain-edit (&rest body)
  "Macro to change buffer.
Example:
    (command-chain-edit
       (insert result)
       (insert prompt))"
  (declare (indent 0))
  `(let ((command-chain-editing t))
     ,@body))

(defun command-chain-insert (&rest args)
  "Shorthand for `insert'."
  (command-chain-edit
    (apply 'insert args)))

(defun command-chain-pass-turn-to-next-player ()
  "Set `command-chain-current-player' to the next player."
  (setq command-chain-current-player
        (% (1+ command-chain-current-player) command-chain-player-count)))

(defun command-chain-current-player-get (key)
  "Shorthand of `command-chain-player-get' to `command-chain-current-player'."
  (command-chain-player-get command-chain-current-player key))

;; game Functions

(defun command-chain-add-change-hooks ()
  "Add hooks to `before-change-functions' and `after-change-functions'."
  (add-hook 'before-change-functions 'command-chain-before-change nil t)
  (add-hook 'after-change-functions 'command-chain-after-change nil t))

(defun command-chain-before-change (from to)
  ;; Discard change if output gets rewritten
  (when (and (not command-chain-editing)
             (< from command-chain-point-after-prompt))
    ;; Hook functions seem to be removed when `signal'ed.
    ;; So `add-hook' again.
    (add-hook 'post-command-hook 'command-chain-add-change-hooks nil t)
    (signal 'text-read-only nil)))

(defun command-chain-after-change (from to old-len)
  ;; Face of the string inserted by players may be set to prompt's one.
  ;; So reset the face.
  (unless command-chain-editing
    (put-text-property from to 'face 'default)))

;; FIXME: change font according to player
(defface command-chain-prompt-face
  '((t :foreground "deep sky blue"))
  "Prompt's face.")

(defun command-chain-prompt ()
  "Print a prompt."
  (let* ((name (command-chain-current-player-get 'name))
         (prompt (concat name "> ")))
    (command-chain--put-property 'face 'command-chain-prompt-face prompt)
    (command-chain-insert prompt))
  (setq command-chain-point-after-prompt (point-max)))

(defun command-chain-process-input (input)
  (let* ((content (s-trim input))
         (ok (commandp (intern content))))
    (command-chain-insert
     content ": " (if ok "" "NOT ") "an interactive function\n")))

(defun command-chain-commit-input ()
  "Commit player's input and prompt next input."
  (interactive)
  (end-of-buffer)
  (command-chain-insert "\n")
  (let ((input (buffer-substring
                command-chain-point-after-prompt (point-max))))
    (command-chain-process-input input)
    (command-chain-pass-turn-to-next-player)
    (command-chain-prompt)))

;; beginning-of-lineなどを機能させるには、Fieldを使う
(defun command-chain-start-game ()
  "Create game buffer and start game."
  (interactive)
  (switch-to-buffer (generate-new-buffer "*Command Chain*"))
  (local-set-key (kbd "RET") 'command-chain-commit-input)
  (command-chain-add-change-hooks)
  (setq command-chain-current-player 0)
  (command-chain-prompt))

(defun command-chain (player-count)
  "Play command chain game, that is, word chain by Emacs commands."
  (interactive "nHow many players: ")
  (when (< player-count 1)
    (error "Number of players must be 1 or more."))
  ;; FIXME
  (setq command-chain-player-count 2)
  (command-chain-config))