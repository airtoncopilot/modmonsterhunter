# Notas da sessão: Buff Timers HUD

Resumo das sessões com o Claude Code, para continuar em outro PC.

- 17/11/2026 (PC do trabalho, sem o jogo): pesquisa e v0.1 de diagnóstico.
- 19/11/2026 (PC de casa, com o jogo): testes, descoberta da ligação ícone → buff e v0.3 funcionando.

## Objetivo

Mod REFramework (Lua) para Monster Hunter Wilds que mostra o **tempo restante de cada buff logo abaixo do ícone dele no HUD** (os ícones perto da barra de vida).

## Decisões tomadas

- **Tipo de mod:** script Lua via REFramework.
- **Desenho:** `draw.text` dentro de `re.on_frame`. Não precisa do plugin Direct2D.
- **Posição:** ancorado na posição real de cada ícone do HUD.
- **Ligação ícone → buff:** aprendida em jogo (ver abaixo), porque os nomes do enum são códigos opacos.
- **Testes:** só no PC de casa. Jogo em `D:\SteamLibrary\steamapps\common\MonsterHunterWilds`.

## O que se sabe

| O quê | Como acessar |
|---|---|
| HUD de vida | `app.GUI020003`, GUIID 51. `GUIManager:getGUI(51)` |
| HUD visível? | `GUIManager:getGUI(51):get_IsVisible()` (`false` em mapa, menus, loading) |
| **Gerenciador dos ícones** | `getGUI(51)._StatusIconManager` (`app.StatusIconManager`) |
| **Lista dos ícones** | `_StatusIconManager._StatusIconInfoList` (array de `app.StatusIconInfo`, 20 posições) |
| Em cada `StatusIconInfo` | `_StatusIcon` (código `app.IconDef.STATUS`, -1 = vazio), `_DispState` (0 = escondido), `<StatusIconPanel>k__BackingField` (o `PNL_STIcon*`), `<TimerText>k__BackingField` (`txt_timerNum`), `Timer` (só preenchido na refeição) |
| Ícones ativos | `_StatusIconManager._ActiveStatusIconList` (List de `app.IconDef.STATUS`) |
| Posição na tela | `app.GUIUtilApp.getScreenPosByGrobalPosition(ctrl:get_GlobalPosition())` |
| Timers de item (s) | `cHunterStatus._ItemBuff`: `_Kairiki_Timer`, `_KijinPowder_Timer`, `_CoolerDrink_Timer`... As drogas (`_KijinDrink`, `_KijinDrink_G`, `_KoukaDrink`...) são objetos com `_Timer`. Desligado = -1 |
| Refeição | `cHunterStatus._MealEffect:get_DurationTimer()` |

Códigos `app.IconDef.STATUS` confirmados em jogo:

| Código | Buff |
|---|---|
| 19 | Refeição |
| 65 | Semente de Poder (`_Kairiki_Timer`) |
| 66 | Pó do Demônio (`_KijinPowder_Timer`) |
| 70 | Bebida Fria (`_CoolerDrink_Timer`) |
| 64 | provavelmente Droga do Demônio G (`_KijinDrink_G`), não confirmado |
| 12, 26, 14 | provavelmente habilidades do equipamento (sem timer de item) |

Lições dos testes:

- Os nomes do enum `app.IconDef.STATUS` são `STATUS_0014`, `STATUS_0064`... Não servem para casar com os campos de `_ItemBuff`.
- O jogo só escreve texto em `txt_timerNum` para a refeição; nos outros fica um "0" escondido.
- `imgui.calc_text_size` dentro de `re.on_frame` usa a fonte do menu do REFramework (maior que a do `draw.text`). Usar largura fixa por caractere.
- Renovar um buff ativo não muda o ícone, então não serve para aprender.
- Não usar hooks em `onOpen`/`onClose` de GUI (derruba o FPS, segundo o wilds-world-hud).

## Estado atual (v0.3)

`reframework/autorun/buff_timers_hud.lua`:

- Lê `_StatusIconInfoList` a cada frame e desenha o tempo sob cada ícone ligado a um timer (`2:35`, `45s`; amarelo < 30 s, vermelho < 10 s). Refeição não é redesenhada.
- **Aprendizado:** evento de timer começando (≤0 → >0) ou zerando, cruzado com ícones que aparecem/somem até 3 s antes ou depois. Os candidatos são cruzados entre usos até sobrar um. Ligações salvas em `reframework/data/buff_timers_hud.json` (`learned`), com as 4 confirmadas já embutidas no script (`KNOWN`).
- Log de eventos em `reframework/data/buff_timers_hud_events.json` (últimos 200).
- Menu: Ativado, Modo inspetor (mostra o código de cada ícone), Deslocamento X/Y, Largura da letra, lista de aprendidos, Esquecer o que foi aprendido, Gerar dump de diagnóstico (inclui reflexão do `_StatusIconManager`).

## Próximos passos

1. Confirmar o código da Droga do Demônio G e dos outros itens (Semente de Armadura, drogas de armadura, Bebida Quente, Pó da Armadura...) e acrescentar em `KNOWN`.
2. Desligar o modo inspetor por padrão na configuração salva quando o mapa estiver completo.
3. Talvez: barra de progresso ou cor por tipo de buff.

Para retomar, um bom pedido inicial é:

> Leia o SESSAO.md. Vamos continuar o Buff Timers HUD.

## Referências

- [HudController](https://github.com/kmy0/HudController) (kmy0): estrutura do HUD, `PNL_STIcon`, conversão de posição para a tela.
- [wilds-world-hud](https://github.com/dirtTW/wilds-world-hud) (dirtTW): IDs da GUI, detecção de menus.
- [mhwilds-hood-overlay](https://github.com/Hoodstrats/mhwilds-hood-overlay) (Hoodstrats): campos dos timers de buff.
- [Buff Timers Overlay (Nexus 1314)](https://www.nexusmods.com/monsterhunterwilds/mods/1314): mod parecido, mas num painel separado.
- [REFramework](https://github.com/praydog/REFramework)
