# Notas da sessão: Buff Timers HUD

Resumo da sessão de 17/11/2026 com o Claude Code, para continuar em outro PC.

## Objetivo

Mod REFramework (Lua) para Monster Hunter Wilds que mostra o **tempo restante de cada buff logo abaixo do ícone dele no HUD** (os ícones perto da barra de vida).

## Decisões tomadas

- **Tipo de mod:** script Lua via REFramework (o REFramework já está instalado no PC do jogo).
- **Desenho:** `draw.text` dentro de `re.on_frame`, do próprio REFramework. Não precisa do plugin Direct2D.
- **Posição:** o texto fica ancorado na posição real de cada ícone do HUD do jogo, não numa posição fixa da tela.
- **Testes:** o jogo **não** está instalado no PC do trabalho. Lá não dá para testar nada; os testes são feitos no PC de casa.

## O que já se sabe (pesquisa)

| O quê | Como acessar | Fonte |
|---|---|---|
| HUD de vida | `app.GUI020003` (GUIID 51, ou enum `app.GUIID.ID.GUI020003`) | wilds-world-hud |
| Raiz do HUD | `GUIManager:get_HudDisplayManager():findDisplayControl(51)._TargetControl` | wilds-world-hud |
| Painel dos ícones | `PNL_Pat00 / PNL_StateIcons` | HudController, wilds-world-hud |
| Cada ícone | filhos `PNL_STIcon*`, cada um com `PNL_timerLong` e `PNL_timerNum` | HudController (`health/skill_list.lua`) |
| Posição na tela | `app.GUIUtilApp.getScreenPosByGrobalPosition(via.vec3)` aplicada em `ctrl:get_GlobalPosition()` | HudController |
| HUD visível? | `GUIManager:getGUI(51):get_IsVisible()`, que fica `false` em mapa, menus e loading | wilds-world-hud |
| Status do caçador | `app.PlayerManager:getMasterPlayer():get_Character():get_HunterStatus()` | mhwilds-hood-overlay |
| Timers de item (segundos) | `cHunterStatus._ItemBuff`: `_Kairiki_Timer`, `_KijinPowder_Timer`, `_HotDrink_Timer`... As drogas (`_KijinDrink`, `_KoukaDrink`...) são objetos com o campo `_Timer` | mhwilds-hood-overlay |
| Refeição | `cHunterStatus._MealEffect:get_DurationTimer()` | mhwilds-hood-overlay |

Avisos encontrados na pesquisa:

- Não usar hooks em `onOpen`/`onClose` de GUI para detectar menus: derrubou o FPS de 90 para 12 nos testes do wilds-world-hud.
- Percorrer a árvore de GUI inteira a cada frame pesa. O script refaz a lista de ícones só a cada 60 frames.

## O que falta descobrir

**Qual ícone `PNL_STIcon*` corresponde a qual buff.** Não está documentado em lugar nenhum público. Hipóteses a checar no dump:

1. O próprio jogo escreve um texto em `PNL_timerNum` (aí basta mostrar ou forçar visível).
2. `app.GUI020003` tem algum campo (lista/array) que liga cada ícone a um tipo de buff.
3. A identidade do ícone vem da textura/região do `via.gui.Texture` dentro dele.

## Estado atual (v0.1, diagnóstico)

- `reframework/autorun/buff_timers_hud.lua`
  - **Modo inspetor** (ligado por padrão): escreve `#1`, `#2`... em amarelo abaixo de cada ícone visível.
  - Se `PNL_timerNum` tiver texto, mostra esse texto.
  - Botão **Gerar dump de diagnostico**: salva `reframework/data/buff_timers_hud_dump.json` com a árvore dos ícones, os timers de buff ativos, os campos de `app.GUI020003` e de `cHunterStatus` e os getters de `via.gui.Texture`.
  - Menu: Ativado, Modo inspetor, Deslocamento X/Y (salvos em `reframework/data/buff_timers_hud.json`).
- Sintaxe validada com `luaparse` (Node). **Ainda não rodou no jogo.**

## Próximos passos (em casa, com o jogo)

1. Copiar a pasta `reframework` deste repositório para a pasta do jogo (`...\steamapps\common\MonsterHunterWilds\`).
2. Entrar no jogo e usar alguns buffs (Semente de Poder, Pó do Demônio, Bebida Fria, comer na cantina).
3. Conferir se `#1`, `#2`... aparecem sob os ícones. Ajustar Deslocamento X/Y se precisar.
4. Se houver erro: menu do REFramework (Insert) → aba de scripts, ou o arquivo `re2_framework_log.txt` na pasta do jogo.
5. Com os buffs ativos: Insert → *Script Generated UI* → **Buff Timers HUD** → **Gerar dump de diagnostico**.
6. Abrir o Claude Code na pasta do repositório e passar para ele:
   - este arquivo (`SESSAO.md`);
   - o `reframework/data/buff_timers_hud_dump.json` (da pasta do jogo);
   - um print da tela com os números sob os ícones.
7. **v0.2:** usar o dump para ligar ícone → buff e trocar `#N` pelo tempo (`2:35`, `45s`), com cor de alerta perto do fim.

Para retomar, um bom pedido inicial é:

> Leia o SESSAO.md e o dump em `<caminho>`. Vamos fazer a v0.2 do Buff Timers HUD.

## Referências

- [HudController](https://github.com/kmy0/HudController) (kmy0): estrutura do HUD, `PNL_STIcon`, conversão de posição para a tela.
- [wilds-world-hud](https://github.com/dirtTW/wilds-world-hud) (dirtTW): IDs da GUI, `docs/gui_ids.csv`, detecção de menus.
- [mhwilds-hood-overlay](https://github.com/Hoodstrats/mhwilds-hood-overlay) (Hoodstrats): campos dos timers de buff.
- [Buff Timers Overlay (Nexus 1314)](https://www.nexusmods.com/monsterhunterwilds/mods/1314): mod parecido, mas num painel separado e não sob os ícones.
- [REFramework](https://github.com/praydog/REFramework)
