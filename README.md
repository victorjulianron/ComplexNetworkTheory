"""Con respecto al código en Main(2).nlogo"""

El modelo simula cómo las empresas financieras (seguros y reaseguros) están conectadas a través de distintas relaciones financieras y cómo se puede propagar el riesgo de quiebra en la red, considerando el error por redondeo en los cálculos financieros.

Turtles (nodos): representan empresas financieras.
Propiedades:
  capital: capital actual de la empresa.
  default-cap: capital inicial.
  distress?: indica si la empresa está en problemas financieros.
  
Links (enlaces): representan relaciones financieras entre empresas.
Propiedades:
  relation-type: tipo de relación (partes-vinculadas, participaciones-cruzadas, garantias-internas).
  exposure: monto de exposición financiera entre empresas.

Sliders
  num-companies: número de empresas en la red.
  max-exposure: exposición financiera máxima de un link.
  roundoff-percent: límite de error por redondeo en los cálculos.
