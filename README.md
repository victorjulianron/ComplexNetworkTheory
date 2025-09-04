Se actualizaron errores de exposicion, se hizo que las entidades centrales, con mas nodos, tengan mas capital y se aumento el numero maximo de entidades financieras



"""Con respecto al código modelofinal.nlogo"""
El modelo permite estudiar cómo se propaga un shock financiero en una red de empresas, considerando errores de redondeo, centralidad de los nodos y la convergencia del sistema. Esto da una herramienta simple de análisis actuarial para observar vulnerabilidades y estabilidad numérica de un sistema financiero interconectado.
Este modelo simula un sistema financiero compuesto por empresas (tortugas), incluyendo seguros y reaseguros, donde:

Cada nodo representa una empresa financiera.

Los enlaces representan relaciones financieras: operaciones con partes vinculadas, participaciones cruzadas o garantías.

Se puede propagar un contagio financiero desde un nodo inicial en distress.

Se calcula un error por redondeo en el capital de cada empresa y se monitorean métricas de error y convergencia.

Tortugas (empresas)

capital: capital actual disponible.

default-cap: capital inicial asignado al crear la tortuga.

distress?: indica si la empresa está en distress (true/false).

round-error-value: el error de redondeo aplicado en el tick actual.

Links (relaciones)

exposure: cantidad de exposición financiera entre dos empresas.

link-type: tipo de relación (“vinculada”, “cruzada” o “garantia”).

Globals

Parámetros de simulación: round-error-rate, convergence-threshold.

Métricas de error: max-error, avg-error, trend-error.

Convergencia: last-total-capital, converged?.

setup

Inicializa el mundo, crea tortugas y enlaces.

Aplica un fondo blanco para contraste.

Selecciona un nodo inicial en distress y lo marca en rojo.

Colorea los nodos según centralidad: los más cercanos al centro son más intensamente azules.

setup-companies

Crea num-companies tortugas con capital aleatorio y tamaño proporcional al capital.

Coloca tortugas dispersas al azar en el espacio.

setup-links

Cada tortuga crea enlaces con otras tortugas según centralidad:

Nodos más centrales tienen más conexiones.

Las relaciones se etiquetan como “vinculada”, “cruzada” o “garantia”.

color-centrality

Aplica un color azul proporcional a la centralidad para nodos no en distress.

Nodos centrales → azul más intenso; nodos periféricos → azul más claro.

go

Cada tick:

Actualiza capital (update-capital).

Propaga contagio desde nodos en distress (contagion).

Actualiza métricas de error (update-error-metrics).

Recalcula colores y layout.

Verifica convergencia (check-convergence).

Avanza un tick.

update-capital

Calcula pérdidas de cada tortuga según exposición de sus enlaces.

Aplica error de redondeo aleatorio (round-error-rate).

Ajusta el capital y actualiza el tamaño visual de la tortuga.

Si capital ≤ 0 → marca la tortuga como distress y cambia a color rojo.

contagion

Las tortugas en distress impactan el capital de sus enlaces en 10% de su exposición.

Esto simula el efecto contagio financiero en la red.

update-error-metrics

Calcula:

max-error: máximo error absoluto de redondeo entre las tortugas.

avg-error: promedio de error absoluto.

trend-error: cambio relativo del error promedio respecto al tick anterior.

Permite monitorear estabilidad numérica de la simulación.

check-convergence

Compara el capital total actual con el capital total del tick anterior.

Si la variación relativa es menor que convergence-threshold → converged? = true.

Permite detectar cuando la simulación ha llegado a un estado estable.

Monitores:

count turtles with [distress?] → empresas en distress

sum [capital] of turtles → capital total

max-error → máximo error de redondeo

avg-error → promedio de error

converged? → indica si el sistema se estabilizó
