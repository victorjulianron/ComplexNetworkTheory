@#$#@#$#@
globals [
  epsilon_machine unit_roundoff cumulative_rounding_bound total_loss
  defaulted_count contagion_threshold base_contagion_prob
  network_density rounding_mode_global
  current_tick_error max_error_so_far average_error error_history
  convergence_counter operations_per_tick num_agents error_threshold
  random_seed rounding_bound_alert_threshold
  critical_float_ops
  forward_error
  backward_error
  significant_digits_loss
  current_rounding_bound_forward
]

breed [insurers insurer]
breed [reinsurers reinsurer]
undirected-links-breed [financial-links financial-link]

insurers-own [ Li Ci Ri lambda_i alpha_i leverage default? rounding_digits ]
reinsurers-own [ Li Ci Ri lambda_i alpha_i leverage default? rounding_digits ]
financial-links-own [ kij exposure_weight ]
patches-own [ shock_intensity liquidity_index volatidity_index rounding_mode_patch ]

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
  output-print "Modelo listo para la simulación avanzada de error."
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

to setup-patches
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
    let precise_loss (lambda_i * random-float 10) * (leverage / 10)
    set critical_float_ops critical_float_ops + 2
    let rounded_loss round-number precise_loss rounding_digits

    let precise_li Li + rounded_loss
    set critical_float_ops critical_float_ops + 1
    let rounded_li round-number precise_li rounding_digits
    set Li rounded_li

    let transferred_loss Li * alpha_i
    set critical_float_ops critical_float_ops + 1
    let precise_new_capital Ci - (Li - transferred_loss)
    set critical_float_ops critical_float_ops + 2
    
    let rounded_new_capital round-number precise_new_capital rounding_digits
    set Ci rounded_new_capital
    if Ci <= 0 [ set default? true set color gray ]
  ]
end

to propagate-contagion
  ask turtles with [default?] [
    let default_impact Ci * 0.1
    set critical_float_ops critical_float_ops + 1
    ask my-links [
      let other_agent [other-end] of self
      if not [default?] of other_agent [
        let contagion_factor [kij] of self
        if random-float 1.0 < (base_contagion_prob * contagion_factor) [
          set critical_float_ops critical_float_ops + 1
          ask other_agent [
            let additional_loss default_impact * ([exposure_weight] of link-from myself)
            set critical_float_ops critical_float_ops + 1
            let precise_li Li + additional_loss
            set critical_float_ops critical_float_ops + 1
            set Li round-number precise_li rounding_digits
          ]
        ]
      ]
    ]
  ]
end

to calculate-centrality
  let total_leverage sum [leverage] of turtles with [not default?]
  set critical_float_ops critical_float_ops + 1
  if total_leverage = 0 [ set total_leverage 1 ]
  ask turtles with [not default?] [
    let neighbor_leverage sum [leverage] of my-links-neighbors with [not default?]
    set critical_float_ops critical_float_ops + 1
    let precise_ri (neighbor_leverage / total_leverage) * count my-links
    set critical_float_ops critical_float_ops + 2
    set Ri round-number precise_ri rounding_digits
    set size 1 + Ri * 5
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
  if ticks > 10 [
    if convergence_counter >= 5 [
      output-print "La simulación ha convergido."
      stop
    ]
  ]
end

to check-error-threshold
  if current_tick_error > error_threshold [
    output-print (word "¡ALERTA! El error de redondeo actual (" precision current_tick_error 4 ") ha superado el umbral crítico.")
    stop
  ]
end

to check-rounding-bound-alert
  if current_rounding_bound_forward > rounding_bound_alert_threshold [
    output-print (word "¡ADVERTENCIA! El límite superior de error de redondeo (" precision current_rounding_bound_forward 4 ") ha excedido el umbral.")
  ]
end

to export-data
  output-print "tick,defaulted_count,total_loss,average_error,max_error,rounding_bound_forward,critical_float_ops,sig_digits_loss"
  let data (list ticks defaulted_count total_loss average_error max_error_so_far current_rounding_bound_forward critical_float_ops significant_digits_loss)
  output-print (word (item 0 data) ", " (item 1 data) ", " (item 2 data) ", " (item 3 data) ", " (item 4 data) ", " (item 5 data) ", " (item 6 data) ", " (item 7 data))
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
@#$#@#$#@
GRAPHICS-WINDOW
210
10
680
480
-1
-1
10.0
1
10
1
1
1
0
1
1
1
-1
-1
1
ticks
30.0

BUTTON
10
10
80
40
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
90
10
160
40
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
170
10
260
40
export-data
export-data
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
60
210
93
random-seed
random-seed
0
1000000
12345
1
1
NIL
HORIZONTAL

SLIDER
10
100
210
133
initial-shock-magnitude
initial-shock-magnitude
0
1
0.2
0.01
1
NIL
HORIZONTAL

SLIDER
10
140
210
173
lambda-range
lambda-range
0.01
0.3
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
10
180
210
213
alpha-range
alpha-range
0
1
0.3
0.05
1
NIL
HORIZONTAL

SLIDER
10
220
210
253
network-density
network-density
0
1
0.2
0.05
1
NIL
HORIZONTAL

SLIDER
10
260
210
293
average-leverage
average-leverage
1
100
10
1
1
NIL
HORIZONTAL

SLIDER
10
300
210
333
rounding-digits
rounding-digits
0
16
4
1
1
NIL
HORIZONTAL

SLIDER
10
340
210
373
rounding-mode-slider
rounding-mode-slider
0
1
0
1
1
NIL
HORIZONTAL

SLIDER
10
380
210
413
error-threshold-slider
error-threshold-slider
0
100
10
1
1
NIL
HORIZONTAL

SLIDER
10
420
210
453
rounding-bound-alert-threshold
rounding-bound-alert-threshold
0
10000
500
10
1
NIL
HORIZONTAL

MONITOR
700
20
850
65
Número de defaults
defaulted_count
17
1
11

MONITOR
700
70
850
115
Pérdida total
total_loss
17
1
11

MONITOR
700
120
850
165
Error medio
average_error
17
1
11

MONITOR
700
170
850
215
Error máximo
max_error_so_far
17
1
11

MONITOR
700
220
850
265
Operaciones críticas
critical_float_ops
17
1
11

MONITOR
700
270
850
315
Pérdida dígitos sig.
significant_digits_loss
17
1
11

PLOT
870
20
1100
180
Defaults vs Tiempo
Tiempo
Defaults
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"defaulted_count" 1.0 0 -16777216 true "" "plot defaulted_count"

PLOT
870
200
1100
360
Error de Redondeo
Tiempo
Error
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Error medio" 1.0 0 -13345367 true "" "plot average_error"
"Error máximo" 1.0 0 -2674135 true "" "plot max_error_so_far"

PLOT
870
380
1100
540
Pérdidas del Sistema
Tiempo
Pérdida
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Pérdida total" 1.0 0 -955883 true "" "plot total_loss"

OUTPUT
210
490
680
680
11
1
11

@#$#@#$#@
