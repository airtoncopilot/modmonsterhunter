# Buff Timers HUD (Monster Hunter Wilds)

Mostra o tempo restante dos buffs logo abaixo dos ícones de status do HUD (os ícones que ficam perto da barra de vida).

**Status: v0.3, funcionando no jogo** (testado em 19/11/2026).

## Requisitos

- [REFramework](https://www.nexusmods.com/monsterhunterwilds/mods/93) instalado no jogo.

## Instalação

1. Copie a pasta `reframework` deste projeto para a pasta do jogo, por exemplo
   `D:\SteamLibrary\steamapps\common\MonsterHunterWilds\`.
   O arquivo precisa ficar em `MonsterHunterWilds\reframework\autorun\buff_timers_hud.lua`.
2. Abra o jogo. O script carrega sozinho. Se o jogo já estiver aberto:
   **Insert** → *ScriptRunner* → *Reset scripts*.

## Como funciona

- O tempo aparece embaixo do ícone como `2:35` ou `45s`: branco, **amarelo** abaixo de 30 s e **vermelho** abaixo de 10 s.
- A refeição não ganha texto extra, porque o jogo já mostra o tempo dela.
- Ícones de habilidades do equipamento ficam sem texto (não têm timer de item).

### Aprendizado dos ícones

O jogo identifica cada ícone por um código (`app.IconDef.STATUS`) cujos nomes não dizem nada
(`STATUS_0014`...). Por isso o mod **aprende sozinho** qual ícone é qual buff:

- quando um ícone aparece no mesmo instante em que o timer de um item começa, ou
- quando um ícone some no mesmo instante em que o timer zera.

Se houver mais de um candidato, ele cruza com os próximos usos até sobrar um só.
O que ele aprende fica salvo em `reframework\data\buff_timers_hud.json`.

**Importante:** renovar um buff que já está ativo não ensina nada (o ícone não muda).
Use o item com o buff desligado ou espere ele acabar.

Já vêm prontos no script:

| Código | Buff |
|---|---|
| 19 | Refeição |
| 65 | Semente de Poder (`_Kairiki_Timer`) |
| 66 | Pó do Demônio (`_KijinPowder_Timer`) |
| 70 | Bebida Fria (`_CoolerDrink_Timer`) |

## Menu (Insert → Script Generated UI → Buff Timers HUD)

- **Ativado**
- **Modo inspetor**: mostra o código de cada ícone (e o tempo, se já souber qual buff é).
- **Deslocamento X/Y** e **Largura da letra**: posição e centralização do texto.
- **Ícones aprendidos**: lista código = timer, e o botão **Esquecer o que foi aprendido**.
- **Gerar dump de diagnostico**: salva `reframework\data\buff_timers_hud_dump.json`.

O mod também grava `reframework\data\buff_timers_hud_events.json` com os últimos eventos
(timers começando/acabando, ícones aparecendo/sumindo, ligações feitas), útil para diagnosticar.

## Créditos das pesquisas

- [HudController](https://github.com/kmy0/HudController) (kmy0): estrutura do HUD e conversão de posição para a tela.
- [wilds-world-hud](https://github.com/dirtTW/wilds-world-hud) (dirtTW): IDs da GUI e visibilidade do HUD.
- [mhwilds-hood-overlay](https://github.com/Hoodstrats/mhwilds-hood-overlay) (Hoodstrats): campos dos timers de buff.
