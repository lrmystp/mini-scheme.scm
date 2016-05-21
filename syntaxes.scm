; syntaxes.scm
(load "./evaluator.scm")
(load "./frame.scm")
(load "./result.scm")

; Exp ::= Const                                   定数
;       | Id                                      変数
;       | (lambda Arg Body)                       λ 抽象
;       | (Exp Exp*)                              関数適用
;       | (quote S-Exp)                           クオート (注1)
;       | (set! Id Exp)                           代入
;       | (let [Id] Bindings Body)                let
;       | (let* Bindings Body)                    let* (注4)
;       | (letrec Bindings Body)                  letrec
;       | (if Exp Exp [Exp])                      条件式(if)
;       | (cond (Exp Exp+)* [(else Exp+)])        条件式(cond) (注5)
;       | (and Exp*)                              条件式(and)
;       | (or Exp*)                               条件式(or)
;       | (begin Exp*)                            逐次実行
;       | (do ((Id Exp Exp)*) (Exp Exp*) Body)    繰り返し


(define (syntax-lambda args env)
  (define err-malformed (new-state (v/t 'error "malformed lambda") env))

  (if (< (length args) 1)
    (new-state err-malformed env)
    (let* ((arg0 (car args)))
      (if (or (not (memq (arg0 'type) '(list empty)))
              (not (check-all (lambda (t) (eq? 'symbol (t 'type)))
                              (arg0 'value))))
        (new-state err-malformed env)
        (let* ((symbols (map (lambda (p) (p 'value)) (arg0 'value)))
               (closure (new-closure symbols (cdr args))))
          (new-state closure env))))))


(define (syntax-quote args env)
  (define err-malformed (new-state (v/t 'error "malformed quote") env))

  (if (not (= (length args) 1))
    err-malformed
    (let ((tree (car args)))
      (new-state tree env))))


(define (syntax-set! args env)
  (define err-malformed (new-state (v/t 'error "malformed set!") env))

  (if (or (not (= (length args) 2))
          (not (eq? 'symbol ((car args) 'type))))
    err-malformed
    (let ((name ((car args) 'value))
          (next-state (evaluate (cadr args) env)))
      (if (next-state 'error?)
        next-state
        (let ((new-env (((next-state 'env) 'replace) name (next-state 'value))))
          ; (begin (display (((new-env 'find) "x") 'value))
          (new-state (v/t 'undef ()) new-env))))))
          ; )


(define (syntax-let args env)
  (define err-malformed (new-state (v/t 'error "malformed let") env))

  (cond ((= (length args) 3) (syntax-named-let args env))
        ((not (= (length args) 2)) err-malformed)
        (else
          (let ((next-state (evaluate-bindings (car args) env)))
            (if (next-state 'error?)
              next-state
              (let* ((bindings ((next-state 'value) 'value))
                     (new-env (frame bindings (next-state 'env)))
                     (result-state (evaluate (cadr args) new-env)))
                (new-state (result-state 'value) ((result-state 'env) 'outer-frame))))))))


(define (syntax-named-let args env)
  (define err-malformed (new-state (v/t 'error "malformed let") env))

  (if (not (eq? ((car args) 'type) 'symbol))
    err-malformed
    (let ((next-state (evaluate-bindings (cadr args) env)))
      (if (next-state 'error?)
        next-state
        (let* ((bindings ((next-state 'value) 'value))
               (symbols (map car bindings))
               (closname ((car args) 'value))
               (body (caddr args))
               (loop (new-closure symbols body))
               (new-env (frame (cons (cons closname loop) bindings) (next-state 'env)))
               (result-state (evaluate body)))
          (new-state (result-state 'value) ((next-state 'env) 'outer-frame)))))))


(define (syntax-let* args env))


(define (syntax-letrec args env))


(define (syntax-if args env)
  (if (not (eq? 3 (length args)))
    (v/t 'error "malformed if")
    (let ((condition (evaluate (car args) env)))
      (cond ((condition 'error?) condition)
            ((condition 'value) (evaluate (cadr args) (condition 'env)))
            (else (evaluate (caddr args) (condition 'env)))))))

(define (syntax-cond args env))

(define (syntax-else args env)
  (v/t 'error "invalid syntax"))

(define (syntax-and args env))

(define (syntax-or args env))

(define (syntax-begin args env))

(define (syntax-do args env))

; utils

(define (evaluate-bindings tree _env)
  (define (loop bindings env)
    (define invalid-syntax (new-state (v/t 'error "invalid syntax") env))

    (if (null? bindings)
      (new-state (v/t 'bindings '()) env)
      (let ((cell (car bindings)))
        (if (or (not (eq? (cell 'type) 'list))
                (not (= (length (cell 'value)) 2)))
          invalid-syntax
          (let ((label (car (cell 'value)))
                (next-state (evaluate (cadr (cell 'value)) env)))
            (cond ((not (eq? 'symbol (label 'type))) invalid-syntax)
                  ((next-state 'error?) next-state)
                  (else
                    (let ((binding (cons (label 'value) (next-state 'value)))
                          (rest (loop (cdr bindings) (next-state 'env))))
                      (if (rest 'error?)
                        rest
                        (new-state (v/t 'bindings (cons binding
                                                        ((rest 'value) 'value)))
                                   (rest 'env)))))))))))
  (loop (tree 'value) _env))


(define (new-closure symbols body)

  (define (evaluate-args args _env)
    (define (loop args env)
      (if (null? args)
        (new-state (v/t 'empty '()) env)
        (let ((state (evaluate (car args) env)))
          (if (state 'error?)
            state
            (let ((rest-st (loop (cdr args) (state 'env))))
              (cond ((rest-st 'error?) rest-st)
                    ((eq? 'empty ((rest-st 'value) 'type))
                     (new-state (v/t 'args (cons (state 'value) '()))
                                (rest-st 'env)))
                    (else
                      (new-state (v/t 'args (cons (state 'value)
                                                  ((rest-st 'value) 'value)))
                                 (rest-st 'env)))))))))

    (loop args _env))

  (define closure (lambda (_args env)
    (if (not (equal? (length symbols) (length _args)))
      (new-state (v/t 'error "wrong number of arguments") env)
      (let ((args (evaluate-args _args env)))
        (if (args 'error?)
          args
          (let* ((new-env (frame (map cons symbols ((args 'value) 'value)) env))
                 (state (evaluate-body body new-env)))
            (new-state (state 'value) env)))))))

  (let ((check-result (check-body body)))
    (if (check-result 'error?)
      check-result
      (v/t 'closure closure))))


(define (evaluate-body body env)
  (define (loop body state)
    (if (null? body)
      state
      (let* ((term (car body))
             (rest (cdr body))
             (next-state (evaluate term (state 'env))))
        (if (next-state 'error?)
          next-state
          (loop rest next-state)))))

  (loop body (new-state (v/t 'undef '()) env)))


(define (check-all pred lst)
  (or (null? lst)
      (and (pred (car lst))
           (check-all pred (cdr lst)))))


(define (check-body body)
  (define (loop body prev-type)
    (if (null? body)
      (if (eq? prev-type 'define)
        (v/t 'error "invalid body form")
        (v/t 'ok "no problem :)"))
      (let* ((term (car body))
             (rest (cdr body)))
        (if (and (not (eq? prev-type 'define)) (eq? (term 'type) 'define))
          (v/t 'error "invalid body form")
          (loop rest (term 'type))))))

  (loop body 'define))
