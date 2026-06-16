import random
from collections import Counter

class Carta:
    def __init__(self, valor, color, efecto=None):
        self.valor = valor
        self.color = color
        self.efecto = efecto

    def __str__(self):
        return f"{self.valor} de {self.color}"

class Jugador:
    def __init__(self, id, nombre, vida=100):
        self.id = id
        self.nombre = nombre
        self.vida = vida
        self.mano = []
        self.turnos_jugados = 0
        self.last_color_use = -3

    def agregar_carta(self, carta):
        self.mano.append(carta)

    def mostrar_mano(self):
        return [str(carta) for carta in self.mano]

class Juego:
    def __init__(self, jugadores):
        self.jugadores = jugadores
        self.mazo = self.crear_mazo()
        random.shuffle(self.mazo)
        self.mesa = []

    def crear_mazo(self):
        colores = ['Rojo', 'Verde', 'Azul', 'Amarillo']
        valores = list(range(0, 10))
        mazo = []
        for color in colores:
            for valor in valores:
                mazo.append(Carta(valor, color))
        return mazo

    def repartir_cartas(self):
        for jugador in self.jugadores:
            for _ in range(7):
                self._dar_carta(jugador)
        # carta inicial en mesa
        carta = self.mazo.pop() if self.mazo else None
        if carta:
            self.mesa.append(carta)
            print(f"Carta inicial en mesa: {carta}")

    def _dar_carta(self, jugador):
        if not self.mazo:
            return None
        carta = self.mazo.pop()
        jugador.agregar_carta(carta)
        return carta

    def mostrar_manos(self):
        for jugador in self.jugadores:
            print(f"{jugador.nombre} tiene: {jugador.mostrar_mano()}")

    def top_mesa(self):
        return self.mesa[-1] if self.mesa else None

    def puede_jugar(self, carta, top=None):
        # Permite jugar si mismo valor, mismo color, o valor == top.valor + 1 (escalera ascendente)
        if top is None:
            top = self.top_mesa()
        if not top:
            return True
        if carta.valor == top.valor or carta.color == top.color:
            return True
        try:
            if carta.valor == top.valor + 1:
                return True
        except TypeError:
            pass
        return False

    def calcular_multiplicador(self, cartas):
        # Multiplicadores (prioridad):
        # 1) Escalera de color (3 cartas consecutivas en orden jugado y mismo color): x5
        # 2) Trío de color (3 cartas mismo valor y mismo color): x4
        # 3) Trío (3 cartas mismo valor, colores pueden diferir): x3
        # 4) Escalera (3 cartas consecutivas en orden jugado, colores cualquiera): x4
        # 5) Pareja (2 cartas mismo valor): x2
        if not cartas:
            return 1
        valores = [c.valor for c in cartas]
        colores = [c.color for c in cartas]
        if len(valores) == 2:
            if valores[0] == valores[1]:
                return 2
            return 1
        if len(valores) == 3:
            # Escalera de color: mismo color y consecutivas en orden jugado
            if colores[0] == colores[1] == colores[2] and valores[0] + 1 == valores[1] and valores[1] + 1 == valores[2]:
                return 5
            # Trío de color: mismo valor y mismo color
            if valores[0] == valores[1] == valores[2] and colores[0] == colores[1] == colores[2]:
                return 4
            # Trío (mismo valor)
            if valores[0] == valores[1] == valores[2]:
                return 3
            # Escalera (consecutivas en orden jugado, colores cualquiera)
            if valores[0] + 1 == valores[1] and valores[1] + 1 == valores[2]:
                return 4
        return 1

    def jugar_por_indices(self, jugador_id, indices):
        # indices: list de 0-based indices in the player's mano, order = play order
        jugador = next((j for j in self.jugadores if j.id == jugador_id), None)
        if not jugador:
            print("Jugador no encontrado")
            return False
        if not indices:
            print("No se seleccionaron cartas")
            return False
        if len(indices) > 3:
            print("Máximo 3 cartas por turno")
            return False
        # verificar índices válidos
        if any(i < 0 or i >= len(jugador.mano) for i in indices):
            print("Índice inválido en selección")
            return False
        # extraer cartas por referencia según índices originales
        cartas_a_jugar = [jugador.mano[i] for i in indices]
        # verificar secuencia jugable en orden dado
        top = self.top_mesa()
        for carta in cartas_a_jugar:
            if not self.puede_jugar(carta, top):
                print(f"No se puede jugar {carta} sobre {top}")
                return False
            top = carta
        # calcular multiplicador y daño
        multiplicador = self.calcular_multiplicador(cartas_a_jugar)
        suma_valores = sum(c.valor for c in cartas_a_jugar)
        daño = suma_valores * multiplicador
        # remover cartas de la mano (por objeto) y añadir a mesa en orden
        for carta in cartas_a_jugar:
            try:
                jugador.mano.remove(carta)
            except ValueError:
                # seguridad: si no está, saltar
                continue
            self.mesa.append(carta)
        rival = next((r for r in self.jugadores if r.id != jugador_id), None)
        if rival:
            rival.vida -= daño
            print(f"{jugador.nombre} juega {', '.join(str(c) for c in cartas_a_jugar)}. Multiplicador x{multiplicador}. {rival.nombre} pierde {daño} vida (resta {rival.vida}).")
        else:
            print(f"{jugador.nombre} juega {', '.join(str(c) for c in cartas_a_jugar)}.")
        # contar el turno como jugado
        jugador.turnos_jugados += 1
        return True

    def robar(self, jugador_id):
        jugador = next((j for j in self.jugadores if j.id == jugador_id), None)
        if not jugador:
            return None
        carta = self._dar_carta(jugador)
        if carta:
            print(f"{jugador.nombre} roba {carta}")
            print(f"Cartas en el mazo: {len(self.mazo)}")
        else:
            # reciclar la mesa excepto la carta tope
            if not self.mesa:
                print("No hay cartas para reciclar.")
                return None
            cartaRestante = self.mesa.pop()
            for carta in self.mesa:
                self.mazo.append(carta)
            self.mesa = [cartaRestante]
            random.shuffle(self.mazo)
            print("Mazo vacío, barajando cartas desde la mesa")
            carta = self._dar_carta(jugador)
            if carta:
                print(f"{jugador.nombre} roba {carta}")
        return carta

    def buscar_mejor_jugada(self, jugador):
        # Buscar todas las jugadas posibles (1-3 cartas), todas las permutaciones para comprobar secuencia
        from itertools import combinations, permutations
        mejor = None
        mejor_daño = 0
        n = len(jugador.mano)
        indices = list(range(n))
        # considerar tamaños 1..3
        for r in range(1, min(3, n) + 1):
            for combo in combinations(indices, r):
                for orden in permutations(combo):
                    cartas = [jugador.mano[i] for i in orden]
                    # verificar jugable en orden
                    top = self.top_mesa()
                    ok = True
                    for c in cartas:
                        if not self.puede_jugar(c, top):
                            ok = False
                            break
                        top = c
                    if not ok:
                        continue
                    mult = self.calcular_multiplicador(cartas)
                    daño = sum(c.valor for c in cartas) * mult
                    # preferir más daño, en empate preferir más cartas
                    if daño > mejor_daño or (daño == mejor_daño and (mejor is None or len(cartas) > len(mejor))):
                        mejor_daño = daño
                        mejor = list(orden)
        return mejor  # lista de índices 0-based en el orden a jugar, o None

    def turno_ai(self, jugador_id):
        jugador = next((j for j in self.jugadores if j.id == jugador_id), None)
        if not jugador:
            return
        # IA: usar cambiar_color cada 3 turnos si conviene (no gasta turno)
        if self.top_mesa():
            color_counts = Counter(c.color for c in jugador.mano)
            if jugador.turnos_jugados - jugador.last_color_use >= 3 and color_counts:
                mejor_color, cnt = color_counts.most_common(1)[0]
                # elegir dos cartas para cambiar a mejor_color
                indices_to_change = [i for i, c in enumerate(jugador.mano) if c.color != mejor_color]
                if len(indices_to_change) >= 2:
                    indices_to_change.sort(key=lambda i: jugador.mano[i].valor, reverse=True)
                    sel = indices_to_change[:2]
                else:
                    sel = sorted(range(len(jugador.mano)), key=lambda i: jugador.mano[i].valor, reverse=True)[:2]
                if sel and len(sel) == 2:
                    if self.cambiar_color(jugador_id, sel, mejor_color):
                        print(f"{jugador.nombre} (IA) cambia color de cartas {sel[0]+1},{sel[1]+1} a {mejor_color}")
        # buscar la mejor jugada y jugarla
        mejor = self.buscar_mejor_jugada(jugador)
        if mejor:
            self.jugar_por_indices(jugador_id, mejor)
            return
        # si no puede jugar, roba una carta y trata de jugarla si es válida
        carta = self.robar(jugador_id)
        if carta:
            jugador = next((j for j in self.jugadores if j.id == jugador_id), None)
            if jugador and self.puede_jugar(carta, self.top_mesa()):
                idx = len(jugador.mano) - 1
                self.jugar_por_indices(jugador_id, [idx])

    def cambiar_color(self, jugador_id, indices, color):
        jugador = next((j for j in self.jugadores if j.id == jugador_id), None)
        if not jugador:
            print("Jugador no encontrado")
            return False
        if not isinstance(indices, (list, tuple)) or len(indices) != 2:
            print("Debes seleccionar exactamente 2 cartas para cambiar color.")
            return False
        if any(i < 0 or i >= len(jugador.mano) for i in indices):
            print("Índice inválido en selección para cambiar color")
            return False
        # cooldown
        if jugador.turnos_jugados - jugador.last_color_use < 3:
            remaining = 3 - (jugador.turnos_jugados - jugador.last_color_use)
            print(f"No puedes cambiar color aún. Te faltan {remaining} turnos para poder usarlo.")
            return False
        for i in indices:
            jugador.mano[i].color = color
        jugador.last_color_use = jugador.turnos_jugados
        print(f"{jugador.nombre} cambia color de cartas {indices[0]+1} y {indices[1]+1} a {color}")
        return True

def juego_terminal():
    jugadores = [Jugador(1, "Alice"), Jugador(2, "Bob")]
    juego = Juego(jugadores)
    juego.repartir_cartas()

    turno = 0  # 0 -> Alice, 1 -> Bob
    while True:
        alice = next(j for j in jugadores if j.id == 1)
        bob = next(j for j in jugadores if j.id == 2)
        if alice.vida <= 0:
            print("Bob gana!")
            break
        if bob.vida <= 0:
            print("Alice gana!")
            break

        if turno == 0:
            # Turno de Alice (usuario)
            played_this_turn = False
            while not played_this_turn:
                print(f"\nCarta en mesa: {juego.top_mesa()}")
                printo = 0
                for i in range(8):
                    for j in range(4):
                        print(40+((i+1)*40)+((j+1)*20))
                        printo += 40+((i+1)*40)+((j+1)*20)
                print(printo)
                print("Tu mano:")
                for idx, c in enumerate(alice.mano, start=1):
                    print(f"{idx}: {c}")
                choice = input("Elige índices (1-3) separados por espacios para jugar, 'd' para robar, o 'z' para cambiar color: ").strip()
                if choice.lower() == 'z':
                    try:
                        parts_idx = input("Elige índices de dos cartas (ej: 1 2): ").strip().split()
                        idxs = [int(p)-1 for p in parts_idx]
                    except ValueError:
                        print("Índices no válidos.")
                        continue
                    color_choice = input("Elige color (Rojo/Verde/Azul/Amarillo): ").strip().capitalize()
                    if color_choice in ['Rojo', 'Verde', 'Azul', 'Amarillo']:
                        changed = juego.cambiar_color(1, idxs, color_choice)
                        # no gasta el turno; permitir otra acción
                        continue
                    else:
                        print("Color no válido.")
                        continue
                if choice.lower() == 'd':
                    juego.robar(1)
                    # robar consume el turno
                    alice.turnos_jugados += 1
                    played_this_turn = True
                    break
                else:
                    try:
                        parts = [p for p in choice.replace(',', ' ').split() if p]
                        indices = [int(p) - 1 for p in parts]
                        if len(indices) == 0:
                            print("No seleccionaste cartas.")
                            alice.turnos_jugados += 1
                            played_this_turn = True
                            break
                        if len(indices) > 3:
                            print("Máximo 3 cartas por turno.")
                            alice.turnos_jugados += 1
                            played_this_turn = True
                            break
                        played = juego.jugar_por_indices(1, indices)
                        # jugar_por_indices incrementa turnos si jugó correctamente
                        if not played:
                            # movimiento inválido consume turno
                            alice.turnos_jugados += 1
                        played_this_turn = True
                        break
                    except ValueError:
                        print("Entrada no válida. Se pasa el turno.")
                        alice.turnos_jugados += 1
                        played_this_turn = True
                        break
            turno = 1
        else:
            # Turno de Bob (IA)
            print("\nTurno de Bob (IA)")
            juego.turno_ai(2)
            turno = 0

        # Si no quedan cartas en las manos y en el mazo, finalizar empate
        manos_vacias = all(len(j.mano) == 0 for j in jugadores)
        if manos_vacias and not juego.mazo:
            print("Empate: no quedan cartas.")
            break

if __name__ == '__main__':
    juego_terminal()



def juego_terminal():
    jugadores = [Jugador(1, "Alice"), Jugador(2, "Bob")]
    juego = Juego(jugadores)
    juego.repartir_cartas()

    turno = 0  # 0 -> Alice, 1 -> Bob
    while True:
        alice = next(j for j in jugadores if j.id == 1)
        bob = next(j for j in jugadores if j.id == 2)
        if alice.vida <= 0:
            print("Bob gana!")
            break
        if bob.vida <= 0:
            print("Alice gana!")
            break

        if turno == 0:
            # Turno de Alice (usuario)
            played_this_turn = False
            while not played_this_turn:
                print(f"\nCarta en mesa: {juego.top_mesa()}")
                print("Tu mano:")
                for idx, c in enumerate(alice.mano, start=1):
                    print(f"{idx}: {c}")
                choice = input("Elige índices (1-3) separados por espacios para jugar, 'd' para robar, o 'z' para cambiar color: ").strip()
                if choice.lower() == 'z':
                    try:
                        parts_idx = input("Elige índices de dos cartas (ej: 1 2): ").strip().split()
                        idxs = [int(p)-1 for p in parts_idx]
                    except ValueError:
                        print("Índices no válidos.")
                        continue
                    color_choice = input("Elige color (Rojo/Verde/Azul/Amarillo): ").strip().capitalize()
                    if color_choice in ['Rojo', 'Verde', 'Azul', 'Amarillo']:
                        changed = juego.cambiar_color(1, idxs, color_choice)
                        # no gasta el turno; permitir otra acción
                        continue
                    else:
                        print("Color no válido.")
                        continue
                if choice.lower() == 'd':
                    juego.robar(1)
                    # robar consume el turno
                    alice.turnos_jugados += 1
                    played_this_turn = True
                    break
                else:
                    try:
                        parts = [p for p in choice.replace(',', ' ').split() if p]
                        indices = [int(p) - 1 for p in parts]
                        if len(indices) == 0:
                            print("No seleccionaste cartas.")
                            alice.turnos_jugados += 1
                            played_this_turn = True
                            break
                        if len(indices) > 3:
                            print("Máximo 3 cartas por turno.")
                            alice.turnos_jugados += 1
                            played_this_turn = True
                            break
                        played = juego.jugar_por_indices(1, indices)
                        # jugar_por_indices incrementa turnos si jugó correctamente
                        if not played:
                            # movimiento inválido consume turno
                            alice.turnos_jugados += 1
                        played_this_turn = True
                        break
                    except ValueError:
                        print("Entrada no válida. Se pasa el turno.")
                        alice.turnos_jugados += 1
                        played_this_turn = True
                        break
            turno = 1
        else:
            # Turno de Bob (IA)
            print("\nTurno de Bob (IA)")
            juego.turno_ai(2)
            turno = 0

        # Si no quedan cartas en las manos y en el mazo, finalizar empate
        manos_vacias = all(len(j.mano) == 0 for j in jugadores)
        if manos_vacias and not juego.mazo:
            print("Empate: no quedan cartas.")
            break

if __name__ == '__main__':
    juego_terminal()