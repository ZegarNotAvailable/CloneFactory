 # Tester Z80
 ## Wersja beta.
- Wystarczą trzy moduły:
  - "boot",
  - CPU,
  - SYS I/O (lub MIK94).
- Można używać bez wyświetlacza (lepiej jednak go mieć).
- Wystarczą trzy klawisze [G],[.] i [=].
- Działa prawie tak samo, jak CA80-BEZ-ROM.
- System startuje z CLK = 2 MHz.
- Po załadowaniu plików z SD zgłasza się monitor CA80.
- Możemy używać komputer tak jak zwykle (jeżeli mamy wyświetlacz i klawiaturę).
- Po uruchomieniu testera [G][=] (program jest w standardowej lokalizacji - 0C000H) wyświetlany jest wynik testu.
  - Na wyświetlaczu siedmiosegmentowym,
  - Na terminalu,
  - Program oblicza wartość CLK i również ją wyświetla,
  - Możemy zwiększyć CLK przez wciśnięcie [=] lub User w module bootloadera,
    - 2.66 MHz,
    - 4 MHz,
    - 8 MHz.
  - Wciśnięcie [.] zmniejsza CLK.
  - Zwiększenie CLK może spowodować zawieszenie systemu.
    - oznacza to, że procesor nie działa prawidłowo i nie należy go używać z takim taktowaniem,
    - tester nie ma możliwości pracy z częstotliwościami wyższymi niż 8 MHZ.
[YouTube](https://youtu.be/Z5U8VseFnzM)
