; repl.scm
(load "./display.scm")
(load "./parser.scm")
(load "./evaluator.scm")
(load "./global-env.scm")
(load "./syntaxes.scm")

(define (repl)
  (define (read-terms code)
    (let loop ((ind 0))
      (if (>= ind (string-length code))
        ind
        (let* ((parse-result (parse-term code ind))
               (tree (car parse-result))
               (next-ind (cdr parse-result)))
          (cond ((eq? 'non-eot next-ind) ind)
                ((eq? 'none (tree 'type)) (string-length code))
                ((tree 'error?) (string-length code))
                (else
                  (let ((result (evaluate tree global-env)))
                    (display "output: ")
                    (write (result 'value))
                    (newline)
                    (loop next-ind))))))))

  (let loop ((left-code ""))
    (let ((raw-line (begin
                  (display ">>> ")
                  (flush)
                  (read-line))))
      (if (and (= 0 (string-length left-code)) (eof-object? raw-line))
        'bye
        (let* ((line (if (eof-object? raw-line) "" raw-line))
               (code (string-append left-code " " line))
               (end-ind (read-terms code))
               (__ (begin
                     (display "left code: ")
                     (display (string-copy code end-ind (string-length code)))
                     (newline)
                     ))
               )
          (loop (string-copy code end-ind (string-length code))))))))
