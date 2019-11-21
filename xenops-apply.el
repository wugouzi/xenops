(defun xenops-apply (ops)
  (cl-flet ((process (lambda (el)
                       (-if-let (op (xenops-apply-get-op-for-element el ops))
                           (save-excursion (funcall op el))))))
    (-if-let (el (xenops-parse-element-at-point))
        (process el)
      (destructuring-bind (beg end region-active)
          (if (region-active-p)
              `(,(region-beginning) ,(region-end) t)
            `(,(point-min) ,(point-max) nil))
        (save-excursion
          (goto-char beg)
          (let (el)
            (while (setq el (xenops-apply-get-next-element end))
              (process el))))
        (and region-active (not (-intersection ops '(xenops-math-image-increase-size
                                                     xenops-math-image-decrease-size)))
             (deactivate-mark))))))

(defun xenops-apply-get-next-element (end)
  "If there is another element, return it and leave point after it.
An element is a plist containing data about a regexp match for a
section of the buffer that xenops can do something to."
  (cl-flet ((next-match-pos (regexp)
                            (save-excursion
                              (if (re-search-forward regexp end t) (match-beginning 0) end))))
    (let ((element (-min-by (lambda (delims1 delims2)
                              (> (next-match-pos (car (plist-get delims1 :delimiters)))
                                 (next-match-pos (car (plist-get delims2 :delimiters)))))
                            (xenops-apply-get-delimiters))))
      (when (re-search-forward (car (plist-get element :delimiters)) end t)
        (let* ((type (plist-get element :type))
               (parser (plist-get (cdr (assq type xenops-ops)) :parser))
               (element (funcall parser element)))
          ;; TODO: This shouldn't be necessary but it sometimes gets
          ;; stuck attempting to process the same block repeatedly.
          (goto-char (plist-get element :end))
          element)))))

(defun xenops-apply-get-op-for-element (el ops)
  (car (-intersection ops (plist-get
                           (cdr (assq (plist-get el :type) xenops-ops))
                           :ops))))

(defun xenops-apply-get-delimiters ()
  (cl-flet ((get-delimiters (type)
                            (mapcar (lambda (delimiters)
                                      `(:type ,type :delimiters ,delimiters))
                                    (plist-get (cdr (assq type xenops-ops)) :delimiters))))
    (apply #'append (mapcar #'get-delimiters (mapcar #'car xenops-ops)))))

(provide 'xenops-apply)