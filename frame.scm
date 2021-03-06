; frame.scm


(define (frame alist outer-frame)
  (lambda (cmd)
    (cond ((eq? cmd 'find)
           (lambda (name)
             (let ((pair (assoc name alist)))
               (cond (pair (cdr pair))
                     ((null? outer-frame)
                      (v/t 'error (string-append "variable `"
                                                 (symbol->string name)
                                                 "' not found")))
                     (else ((outer-frame 'find) name))))))
          ((eq? cmd 'push!)
           (lambda (symbol value)
             (frame (set! alist (cons (cons symbol value) alist))
                    outer-frame)))
          ((eq? cmd 'replace!)
           (lambda (symbol value)
             (let ((pair (assoc symbol alist)))
               (cond (pair (begin
                             (set! alist (cons (cons symbol value) alist))
                             (v/t 'undef "value replaced successfully")))
                     ((null? outer-frame)
                      (v/t 'error (string-append "variable `" symbol "' not found")))
                     (else ((outer-frame 'replace!) symbol value)))))))))
