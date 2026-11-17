# Buff Timers HUD (Monster Hunter Wilds)

Mostra o tempo restante dos buffs logo abaixo dos ícones de status do HUD (os ícones que ficam perto da barra de vida).

**Status: v0.1, versão de diagnóstico.** Ainda não foi testada no jogo.

## Requisitos

- [REFramework](https://www.nexusmods.com/monsterhunterwilds/mods/93) instalado no jogo.

## Instalação

1. Copie a pasta `reframework` deste projeto para a pasta do jogo, por exemplo
   `C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds\`.
   O arquivo precisa ficar em `MonsterHunterWilds\reframework\autorun\buff_timers_hud.lua`.
2. Abra o jogo. O script carrega sozinho.

## Teste da v0.1

1. Entre numa missão ou área aberta e use alguns itens de buff (Semente de Poder, Pó do Demônio, Bebida Fria etc.).
2. Com o **modo inspetor** ligado (padrão), deve aparecer `#1`, `#2`, ... em amarelo embaixo de cada ícone de buff.
   - Se os números estiverem fora do lugar, ajuste **Deslocamento X/Y** no menu.
   - Se não aparecer nada, veja se há erros na aba de scripts do REFramework.
3. Abra o menu do REFramework (**Insert**) → *Script Generated UI* → **Buff Timers HUD**
   e clique em **Gerar dump de diagnostico**, *com os buffs ativos*.
4. Me envie:
   - o arquivo `MonsterHunterWilds\reframework\data\buff_timers_hud_dump.json`
   - um print da tela mostrando os ícones com os números `#1`, `#2`, ...

Com o dump dá para ver como o jogo liga cada ícone ao seu buff. Na v0.2 os números viram o tempo real (`2:35`, `45s`...).

## Por que precisa do dump

O caminho até os ícones já é conhecido (`app.GUI020003` → `PNL_Pat00/PNL_StateIcons/PNL_STIcon*`),
assim como o tempo dos buffs (`app.cHunterStatus._ItemBuff`, em segundos). O que ninguém documentou é
**qual ícone corresponde a qual buff**, e isso só dá para descobrir com o jogo rodando.

## Créditos das pesquisas

- [HudController](https://github.com/kmy0/HudController) (kmy0): estrutura do HUD e conversão de posição para a tela.
- [wilds-world-hud](https://github.com/dirtTW/wilds-world-hud) (dirtTW): IDs da GUI e visibilidade do HUD.
- [mhwilds-hood-overlay](https://github.com/Hoodstrats/mhwilds-hood-overlay) (Hoodstrats): campos dos timers de buff.
