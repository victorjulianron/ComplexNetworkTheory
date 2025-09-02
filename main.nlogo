;; =========================================================================
;; NetLogo Final Code - Financial Contagion & Advanced Error Analysis
;; =========================================================================
;; Autor: Gemini AI
;; Fecha: 29 de agosto de 2025
;; Versión: 3.0 (Advanced Metrics)
;; Descripción: Modelo con métricas avanzadas para una evaluación profunda de la
;;              precisión numérica y estabilidad en redes de reaseguro.
;; =========================================================================

;; Agentes y Propiedades
breed [insurers insurer]
breed [reinsurers reinsurer]
undirected-links-breed [financial-links financial-link]

insurers-own [ Li Ci Ri lambda_i alpha_i leverage default? rounding_digits ]
reinsurers-own [ Li Ci Ri lambda_i alpha_i leverage default? rounding_digits ]
financial-links-own [ kij exposure_weight ]
patches-own [ shock_intensity liquidity_index volatidity_index rounding_mode_patch ]

;; Variables Globales Críticas (Actualizadas)
globals [
  epsilon_machine unit_roundoff cumulative_rounding_bound total_loss
  defaulted_count contagion_threshold base_contagion_prob
  network_density rounding_mode_global
  current_tick_error max_error_so_far average_error error_history
  convergence_counter operations_per_tick num_agents error_threshold
  random_seed rounding_bound_alert_threshold
  critical_float_ops ;; NUEVO: Contador de operaciones críticas
  forward_error ;; NUEVO: Para el ratio de estabilidad
  backward_error ;; NUEVO: Para el ratio de estabilidad
  significant_digits_loss ;; NUEVO: Pérdida de dígitos significativos
  current_rounding_bound_forward ;; NUEVO: Límite de error hacia adelante
]

;; Parámetros Ajustables (Sliders)
;; @param random-seed: 0 - 1000000
;; @param initial-shock-magnitude: 0 – 1
;; @param lambda-range: 0.01 – 0.3
;; @param alpha-range: 0 – 1
;; @param network-density: 0 – 1
;; @param average-leverage: 1 – 100
;; @param rounding-digits: 0 – 16
;; @param rounding-mode-slider: 0 (clásico) – 1 (estocástico)
;; @param error-threshold-slider: 0 – 100
;; @param rounding-bound-alert-threshold: 0 - 10000

;; =========================================================================
;; PROCEDIMIENTOS DE SETUP Y CONFIGURACIÓN
;; =========================================================================
to setup
  clear-all
  random-seed random_seed
  setup-globals
  setup-patches
  create-agents
  create-network
  reset-metrics
  reset-error-metrics
  ask patches [ set pcolor scale-color white random-float 1 ]
  repeat 100 [ layout-spring ]
  user-message "Modelo listo para la simulación avanzada de error."
end

to setup-globals
  set-default-shape insurers "circle"
  set-default-shape reinsurers "square"
  set-default-color insurers blue
  set-default-color reinsurers red
  set contagion_threshold 0.5
  set base_contagion_prob 0.1
  set unit_roundoff 2 ^ -53
  set operations_per_tick 20
  set rounding_mode_global ifelse-value (rounding-mode-slider = 0) ["classic"] ["stochastic"]
  set error_threshold error-threshold-slider
end

to create-agents
  create-insurers (round (count patches * 0.8)) [
    set Ci (leverage * random-float 100)
    set Li 0 set Ri 0 set lambda_i lambda-range * (1 + random-float 0.5)
    set alpha_i alpha-range * (1 + random-float 0.5)
    set leverage average-leverage * (1 + random-float 0.2)
    set default? false set rounding_digits rounding-digits set size 1
  ]
  create-reinsurers (round (count patches * 0.2)) [
    set Ci (leverage * random-float 200)
    set Li 0 set Ri 0 set lambda_i lambda-range * (1 + random-float 0.5)
    set alpha_i alpha-range * (1 + random-float 0.5)
    set leverage average-leverage * (1 + random-float 0.2)
    set default? false set rounding_digits rounding-digits set size 1
  ]
  set num_agents count turtles
end

to create-network
  repeat (round (num_agents * (num_agents - 1) / 2 * network-density)) [
    let p1 one-of turtles with [not default?]
    let p2 one-of turtles with [p1 != self and not default?]
    if p1 != nobody and p2 != nobody and not link-exists? p1 p2 [
      create-link-with p2 [ set kij random-float 1.0 set exposure_weight random-float 1.0 ]
    ]
  ]
end

to reset-metrics
  set total_loss 0 set defaulted_count 0 set convergence_counter 0
end

to reset-error-metrics
  set error_history [] set current_tick_error 0 set max_error_so_far 0 set average_error 0
  set critical_float_ops 0 set forward_error 0 set backward_error 0 set significant_digits_loss 0
  set current_rounding_bound_forward 0
end

;; =========================================================================
;; PROCEDIMIENTOS DE SIMULACIÓN Y ANÁLISIS
;; =========================================================================
to go
  if count turtles with [not default?] = 0 or ticks > 250 [ stop ]
  tick
  update-agents
  if ticks mod 5 = 0 [ calculate-centrality ]
  propagate-contagion
  calculate-and-track-error
  update-metrics
  check-convergence
  check-error-threshold
  check-rounding-bound-alert
  update-plots
end

to update-agents
  ask turtles with [not default?] [
    let precise_loss (lambda_i * random-float 10) * (leverage / 10) ;; 2 ops
    set critical_float_ops critical_float_ops + 2
    let rounded_loss round-number precise_loss rounding_digits

    let precise_li Li + rounded_loss ;; 1 op
    set critical_float_ops critical_float_ops + 1
    let rounded_li round-number precise_li rounding_digits
    set Li rounded_li

    let transferred_loss Li * alpha_i ;; 1 op
    set critical_float_ops critical_float_ops + 1
    let precise_new_capital Ci - (Li - transferred_loss) ;; 2 ops
    set critical_float_ops critical_float_ops + 2
    
    let rounded_new_capital round-number precise_new_capital rounding_digits
    set Ci rounded_new_capital
    if Ci <= 0 [ set default? true set color gray ]
  ]
end

to propagate-contagion
  ask turtles with [default?] [
    let default_impact Ci * 0.1 ;; 1 op
    set critical_float_ops critical_float_ops + 1
    ask my-links [
      let other_agent [other-end] of self
      if not [default?] of other_agent [
        let contagion_factor [kij] of self
        if random-float 1.0 < (base_contagion_prob * contagion_factor) [ ;; 1 op
          set critical_float_ops critical_float_ops + 1
          ask other_agent [
            let additional_loss default_impact * ([exposure_weight] of link-from myself) ;; 1 op
            set critical_float_ops critical_float_ops + 1
            let precise_li Li + additional_loss ;; 1 op
            set critical_float_ops critical_float_ops + 1
            set Li round-number precise_li rounding_digits
          ]
        ]
      ]
    ]
  ]
end

to calculate-centrality
  let total_leverage sum [leverage] of turtles with [not default?] ;; 1 op
  set critical_float_ops critical_float_ops + 1
  if total_leverage = 0 [ set total_leverage 1 ]
  ask turtles with [not default?] [
    let neighbor_leverage sum [leverage] of my-links-neighbors with [not default?] ;; 1 op
    set critical_float_ops critical_float_ops + 1
    let precise_ri (neighbor_leverage / total_leverage) * count my-links ;; 2 ops
    set critical_float_ops critical_float_ops + 2
    set Ri round-number precise_ri rounding_digits
    set size 1 + Ri * 5 ;; 2 ops
    set critical_float_ops critical_float_ops + 2
  ]
end

to calculate-and-track-error
  set current_tick_error 0
  let total_precise_value 0
  let total_rounded_value 0
  let max_value_current_tick 0

  ask turtles [
    let precise Li
    let rounded round-number precise rounding_digits
    set current_tick_error current_tick_error + abs(precise - rounded)
    
    set total_precise_value total_precise_value + precise
    set total_rounded_value total_rounded_value + rounded
    
    if precise > max_value_current_tick [ set max_value_current_tick precise ]
  ]
  
  set error_history lput current_tick_error error_history
  
  if current_tick_error > max_error_so_far [ set max_error_so_far current_tick_error ]
  set average_error mean error_history
  
  set forward_error abs(total_rounded_value - total_precise_value)
  set backward_error forward_error / max_value_current_tick
  
  if max_value_current_tick > 0 [
    set significant_digits_loss - log10(abs(forward_error) / max_value_current_tick)
    if significant_digits_loss < 0 [ set significant_digits_loss 0 ]
  ]
  
  set current_rounding_bound_forward unit_roundoff * total_precise_value * critical_float_ops
  
  set cumulative_rounding_bound (operations_per_tick * num_agents * unit_roundoff) * ticks
end

to update-metrics
  set total_loss sum [Li] of turtles
  set defaulted_count count turtles with [default?]
end

to check-convergence
  if ticks > 10 and (item (ticks - 1) [defaulted_count] of globals) = defaulted_count [
    set convergence_counter convergence_counter + 1
  ]
  if convergence_counter >= 5 [
    user-message "La simulación ha convergido."
    stop
  ]
end

to check-error-threshold
  if current_tick_error > error_threshold [
    user-message (word "¡ALERTA! El error de redondeo actual (" precision current_tick_error 4 ") ha superado el umbral crítico.")
    stop
  ]
end

to check-rounding-bound-alert
  if current_rounding_bound_forward > rounding_bound_alert_threshold [
    user-message (word "¡ADVERTENCIA! El límite superior de error de redondeo (" precision current_rounding_bound_forward 4 ") ha excedido el umbral. La fiabilidad numérica puede estar comprometida.")
  ]
end

to export-data
  file-open "simulation_data.csv"
  file-print "tick,defaulted_count,total_loss,average_error,max_error,rounding_bound_forward,critical_float_ops,sig_digits_loss"
  let data_points n-of (length error_history) [
    list ticks defaulted_count total_loss average_error max_error_so_far current_rounding_bound_forward critical_float_ops significant_digits_loss
  ]
  foreach data_points [
    file-print (word item 0 ? ", " item 1 ? ", " item 2 ? ", " item 3 ? ", " item 4 ? ", " item 5 ? ", " item 6 ? ", " item 7 ?)
  ]
  file-close
  user-message "Datos de la simulación exportados a simulation_data.csv"
end

to-report round-number [num prec]
  if rounding_mode_global = "classic" [ report precision num prec ]
  let factor 10 ^ prec
  let num_shifted num * factor
  let num_int floor num_shifted
  let remainder num_shifted - num_int
  if random-float 1.0 < remainder [ report (num_int + 1) / factor ]
  report num_int / factor
end
