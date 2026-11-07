;;; =====================================================================
;;;  LL.lsp  -  quick total LENGTH (LL) and total AREA (AS) of selected objects
;;;  AutoCAD 2021-2026.  Sergei Grishutov, 2026 - written with AI assistance, MIT license
;;;
;;;  LL  (or SUMLEN)  - select lines / polylines / arcs / circles / splines ...
;;;                     -> sum of their lengths
;;;  AS  (or SUMAREA) - select closed polylines / circles / hatches / regions ...
;;;                     -> sum of their areas
;;;  Objects can be selected before or after the command.
;;;  Result: window + command line, in m / m2 (drawing units from INSUNITS;
;;;  if units are not set, mm is assumed). The number is also copied to the
;;;  clipboard - Ctrl+V straight into Excel.
;;; =====================================================================
(vl-load-com)

;;; ---- settings (change here if needed)
(setq *ll-dec*   2)   ; decimals in the result
(setq *ll-popup* T)   ; T = show the result in a window, nil = command line only
(setq *ll-clip*  T)   ; T = copy the number to the clipboard

;;; ---- helpers
(defun ll:try (f args / r)
  (if (vl-catch-all-error-p (setq r (vl-catch-all-apply f args))) nil r)
)
(defun ll:k (/ u)                       ; drawing unit -> metre
  (setq u (getvar "INSUNITS"))
  (cond ((= u 5) 0.01) ((= u 6) 1.0) ((= u 1) 0.0254) ((= u 2) 0.3048) (T 0.001))
)
(defun ll:uname (/ u)
  (setq u (getvar "INSUNITS"))
  (cond ((= u 5) "cm") ((= u 6) "m") ((= u 1) "in") ((= u 2) "ft") (T "mm"))
)
(defun ll:sel (flt / ss)
  (setq ss (cond ((ssget "_I" flt)) ((ssget flt))))
  (sssetfirst nil nil)
  ss
)
(defun ll:curvelen (e)
  (vlax-curve-getDistAtParam e (vlax-curve-getEndParam e))
)
(defun ll:mesh-p (ed)                   ; polyface / polygon mesh - not a line
  (and (= (cdr (assoc 0 ed)) "POLYLINE") (/= 0 (logand 80 (cdr (assoc 70 ed)))))
)
(defun ll:closed-p (e / len)
  (or (vlax-curve-isClosed e)
      (and (setq len (ll:try 'll:curvelen (list e)))
           (> len 1e-9)
           (< (distance (vlax-curve-getStartPoint e) (vlax-curve-getEndPoint e)) 1e-4)
      )
  )
)
(defun ll:setclip (str / html)
  (setq html (vlax-create-object "htmlfile"))
  (vlax-invoke (vlax-get (vlax-get html 'parentWindow) 'clipboardData) 'setData "Text" str)
  (vlax-release-object html)
  T
)
(defun ll:dsep (/ ds)                   ; Windows decimal symbol (for Excel)
  (setq ds (vl-registry-read "HKEY_CURRENT_USER\\Control Panel\\International" "sDecimal"))
  (if (and ds (/= ds "")) ds ".")
)
;; show the result: lab = "Total length", v = value in m / m2, un = "m" / "m2",
;; raw = value in drawing units, n = counted objects, msg = note about skipped objects
(defun ll:show (lab v un raw rawun n msg / dz s ds c clip)
  (setq dz (getvar "DIMZIN"))
  (setvar "DIMZIN" 0)
  (setq s    (rtos v 2 *ll-dec*)
        ds   (ll:dsep)
        clip (if (/= ds ".") (vl-string-subst ds "." s) s)
        c    (and *ll-clip* (ll:try 'll:setclip (list clip)))
  )
  (setq s (strcat lab " = " s " " un
                  "\n" (itoa n) " objects;  in drawing units: " (rtos raw 2 1) " " rawun
                  (if (/= msg "") (strcat "\n" msg) "")
                  (if (member (getvar "INSUNITS") '(1 2 4 5 6)) "" "\nDrawing units not set (INSUNITS) - mm assumed")
                  (if c "\n(copied - Ctrl+V in Excel)" "")
          )
  )
  (setvar "DIMZIN" dz)
  (princ (strcat "\n" s))
  (if *ll-popup* (alert s))
)

;;; ---- LL: total length
(defun c:LL (/ ss i e ed typ len tot n nskip)
  (princ "\nTotal LENGTH - select objects: ")
  (if (setq ss (ll:sel '((0 . "LINE,ARC,CIRCLE,ELLIPSE,SPLINE,LWPOLYLINE,POLYLINE,REGION"))))
    (progn
      (setq i 0 tot 0.0 n 0 nskip 0)
      (repeat (sslength ss)
        (setq e   (ssname ss i)
              i   (1+ i)
              ed  (entget e)
              typ (cdr (assoc 0 ed))
              len (cond ((= typ "REGION") (ll:try 'vla-get-Perimeter (list (vlax-ename->vla-object e))))
                        ((ll:mesh-p ed) nil)
                        (T (ll:try 'll:curvelen (list e)))
                  )
        )
        (if len (setq tot (+ tot len) n (1+ n)) (setq nskip (1+ nskip)))
      )
      (ll:show "Total length" (* tot (ll:k)) "m" tot (ll:uname) n
               (if (> nskip 0) (strcat (itoa nskip) " objects without length skipped") ""))
    )
    (princ "\nNothing selected.")
  )
  (princ)
)

;;; ---- AS: total area
(defun c:AS (/ ss i e ed typ a tot n nopen k)
  (princ "\nTotal AREA - select closed objects: ")
  (if (setq ss (ll:sel '((0 . "CIRCLE,ELLIPSE,SPLINE,LWPOLYLINE,POLYLINE,HATCH,REGION"))))
    (progn
      (setq i 0 tot 0.0 n 0 nopen 0 k (ll:k))
      (repeat (sslength ss)
        (setq e   (ssname ss i)
              i   (1+ i)
              ed  (entget e)
              typ (cdr (assoc 0 ed))
              a   (cond ((member typ '("HATCH" "REGION")) (ll:try 'vla-get-Area (list (vlax-ename->vla-object e))))
                        ((ll:mesh-p ed) nil)
                        ((ll:closed-p e) (ll:try 'vlax-curve-getArea (list e)))
                        (T nil)
                  )
        )
        (if a (setq tot (+ tot a) n (1+ n)) (setq nopen (1+ nopen)))
      )
      (ll:show "Total area" (* tot k k) "m2" tot (strcat (ll:uname) "2") n
               (if (> nopen 0) (strcat (itoa nopen) " open objects (no area) skipped") ""))
    )
    (princ "\nNothing selected.")
  )
  (princ)
)

;;; ---- long names
(defun c:SUMLEN () (c:LL))
(defun c:SUMAREA () (c:AS))

(princ "\nLL loaded: LL - total length, AS - total area (also SUMLEN / SUMAREA).")
(princ)
