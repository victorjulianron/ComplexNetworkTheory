;; =========================================================================
;; NetLogo Web - Modelo Interactivo de Seguros y Reaseguros con Contagio
;; =========================================================================

globals [
  roundoff-error ;; límite de error por redondeo
]

turtles-own [
  capital      ;; capital de la empresa
  default-cap  ;; capital inicial
  distress?    ;; si la empresa está en problemas financieros
]

links-own [
  relation-type  ;; "partes-vinculadas", "participaciones-cruzadas", "garantias-internas"
  exposure       ;; monto de exposición financiera
]

;; =========================================================================
;; SLIDERS (crear en NetLogo Web):
;; num-companies: [5 - 50], valor inicial: 20
;; max-exposure: [100 - 1000], valor inicial: 500
;; roundoff-percent: [0 - 5], valor inicial: 1
;; =========================================================================

;; =========================================================================
;; SETUP
;; =========================================================================
to setup
  clear-all
  set roundoff-error roundoff-percent / 100 ;; convertir % a fracción

  create-turtles num-companies [
    setxy random-xcor random-ycor
    set default-cap 1000 + random 500
    set capital default-cap
    set distress? false
    set color blue
  ]

  setup-links
  reset-ticks
end

to setup-links
  ask turtles [
    ;; corregido: min list para NetLogo Web y sort para convertir agentset a lista
    let partners sort n-of (min list 3 count other turtles) other turtles
    foreach partners [ partner ->
      create-link-with partner [
        set relation-type one-of ["partes-vinculadas" "participaciones-cruzadas" "garantias-internas"]
        set exposure random-float max-exposure

        ;; Colores según tipo de relación
        let link-color orange ;; valor por defecto
        if relation-type = "partes-vinculadas" [ set link-color red ]
        if relation-type = "participaciones-cruzadas" [ set link-color green ]
        ;; Garantías internas mantienen color naranja
        set color link-color
      ]
    ]
  ]
end

;; =========================================================================
;; GO - Evolución Financiera con Contagio
;; =========================================================================
to go
  ask turtles [
    update-capital
  ]

  ask turtles with [distress? = true] [
    propagate-distress
  ]

  ask turtles [
    check-distress
  ]

  tick
end

;; =========================================================================
;; FUNCIONES DE ACTUALIZACIÓN
;; =========================================================================
to update-capital
  let loss 0
  ask my-links [
    let raw-loss exposure * 0.05
    let rounded-loss round (raw-loss * (1 + random-float roundoff-error))
    set loss loss + rounded-loss
  ]
  set capital capital - loss
end

to check-distress
  ifelse capital < default-cap * 0.5 [
    set distress? true
    set color red
  ] [
    set distress? false
    set color blue
  ]
end

to propagate-distress
  ask my-links [
    if [distress?] of other-end = false [
      let factor 0.05
      if relation-type = "partes-vinculadas" [ set factor 0.08 ]
      if relation-type = "participaciones-cruzadas" [ set factor 0.06 ]
      if relation-type = "garantias-internas" [ set factor 0.04 ]

      let contagion-loss round (exposure * factor * (1 + random-float roundoff-error))
      ask other-end [
        set capital capital - contagion-loss
      ]
    ]
  ]
end

;; =========================================================================
;; VISUALIZACIÓN Y ESTADO
;; =========================================================================
to-report network-status
  report (list (count turtles with [distress? = true])
               (count turtles))
end
