> Cópia do vault do dono em 14/11/2026 14:36, com as linhas da tela (escala, aviso de girar e menu inicial) de 14/11/2026 15:48. Não edite aqui: proponha a mudança ao dono, que atualiza a fonte e recopia.

# Five Sols on Mars

O jogo do time para o desafio Junior Astronaut Mission Trainer. Voltar para nasa-spaceapps-26. Os termos estão no [glossário](glossario.md).

Desenho fechado pelo dono em 13/11/2026, antes do hackathon, como base para o primo, que fica com o game design e a programação. Cada item leva uma marca:
- **[R] restrição:** vem do desafio, do dado, da pesquisa ou do regulamento, e não muda sem reabrir a fonte;
- **[P] proposta:** o primo pode trocar no sábado.

Nada de código, cena nem asset antes de 14/11 (regulamento).

Wireframe das telas (14/11): https://claude.ai/artifact/QotyJYnZuz6gMMqdJPpPHE. As marcas R e P dele seguem esta spec; W é escolha do wireframe, que o primo troca livremente. O turno do wireframe ainda mostra o HUD fixo; o mapa da sala em "Onde a criança está" vale acima dele.

## O jogo

Uma criança de 7 a 12 anos comanda por 5 sóis um posto na cratera Gale, em Marte, de dentro do módulo de comando. Ela divide a energia, faz tarefas de uma tela e se protege das tempestades do Sol e da poeira. Sai sabendo que toda escolha tem custo. É um **treinador de missão**: a falha reinicia o sol no simulador, e o fim da missão é um debriefing.

- **[R]** Marte, não a Lua: [0001](decisoes/0001-o-posto-do-jogo-fica-em-marte-nao-na-lua.md).
- **[R]** Navegador, sem download e sem conta (desafio). Godot 4.7.2 com renderer Compatibility e export Web single-threaded (godot-primeira-pessoa-pixel-art (pesquisa no vault do dono)).
- **[R]** No ar no GitHub Pages (github-pages-e-coleta-zero (pesquisa no vault do dono)).
- **[P]** Nome: Five Sols on Mars (nome-do-jogo (pesquisa no vault do dono)).
- **[R]** Inglês por padrão e português com seletor, com as strings numa tabela CSV desde a primeira hora.
- **[R]** Em português, o termo "sol" segue a regra do glossário.

## Barras

Três barras e nenhuma escolha segura sem custo (desafio: de 2 a 3 recursos centrais).

| Barra | O que é | Enche com | Esvazia com |
|---|---|---|---|
| **Energia** | Estoque na bateria | Painel solar, a cada sol (menos com poeira) | Aquecimento da noite, gerador de oxigênio, tarefas de ciência |
| **Oxigênio** | Estoque | Gerador tipo MOXIE, que transforma o CO2 do ar e gasta energia | A tripulação respira, todo sol |
| **Margem de radiação** | Quanto ainda pode receber | Nunca enche | Radiação de cada sol; muito mais na tempestade solar |

- **[R]** Todas as barras seguem uma regra só: cheia é bom, vazia é perigo.
- **[R]** Cada barra leva ícone, texto e número, nunca só cor.
- **[R]** O **medidor de radiação**, com dois limiares (atenção e ir para o abrigo), fica separado das barras, como o sensor da Orion (operacao-real-em-marte-para-o-jogo (pesquisa no vault do dono)).
- **[R]** As proporções vêm do dado:
  - cada pessoa respira cerca de 0,9 kg de O2 por dia;
  - o oxigênio custa de 8 a 12 kWh/kg num MOXIE em escala real (inferência sobre números da NASA);
  - a dose média em Gale triplicou em maio de 2024;
  - limite de 250 mSv por evento solar.

  Fontes: recursos-de-habitat-lunar-e-marciano (pesquisa no vault do dono) e dados-nasa-do-junior-astronaut (pesquisa no vault do dono).
- **[P]** Os números do jogo, os máximos e os limiares das estrelas são do primo. A [página de calibração](https://claude.ai/artifact/BbJQ9PyK6rhk4C3jKahBzE) simula os 5 sóis com três estratégias (tudo em ciência, equilibrada, conservadora) em todos os sóis de início da poeira e avisa quando uma domina.

A troca com custo, decidida pelo dono em 14/11:

- **[R]** A energia que sobra do plano vai sozinha para a bateria. Guardar custa a ciência que não se fez, e não há controle "guardar".
- **[R]** A bateria tem teto, e o excedente se perde. **[P]** O valor, calibrado para que o teto não seja o que decide o jogo.
- **[R]** O O2 produzido a mais fica no tanque, até o máximo dele: é a troca "reserva de oxigênio por pesquisa" das perguntas-guia do desafio.
- **[R]** O **aquecimento da noite** sai da energia todo sol, antes do plano e sem escolha. É uma linha fixa na fase de plano, não uma 4ª barra. É o que dá à bateria função própria na tempestade de poeira, porque o tanque de O2 sozinho não cobre o aquecimento. Base: o Opportunity em 2018 e o InSight em 2022 pararam sem energia para os aquecedores de sobrevivência. **[P]** O valor; o de partida é 1 contra 8 do painel.

## Missão e sol

- **[P]** A missão tem 5 sóis.
- **[R]** O sol 1 é guiado, um passo por vez, sem evento. Do 2º ao 5º ano, instruir antes funciona melhor que deixar tentar (jogos-educativos-7-a-12-anos (pesquisa no vault do dono)).
- **[P]** A voz do tutorial é a mensagem do controle da missão.
- Cada sol tem duas fases:
  - **[R] Fase de plano**, sem relógio. A criança lê o aviso do clima espacial, divide a energia entre oxigênio, tarefas de ciência e bateria, e vê o efeito previsto de cada escolha antes de confirmar. Todo texto mora aqui.
  - **[R] Fase de turno**, curta e em tempo real, só clique e sem texto para ler. Aparecem as tarefas de ciência escolhidas no plano mais as tarefas de manutenção que a base pede, numa lista como a do Among Us.
  - **[P]** O turno dura de 60 a 90 s, com 1 s = 1 min de tempo real.
- **[R]** Um evento por vez. A crise permanente cansa, e a Innersloth a tirou do Among Us (referencias-de-jogos-de-gestao (pesquisa no vault do dono)).
- **[R]** Critério da calibração (14/11): nenhuma estratégia pode ser melhor ou igual às outras duas em ciência e em modos de segurança em todos os cenários. Uma estratégia cautelosa demais pode sair perdendo: cautela que custa caro também é lição, e não viola "nenhuma escolha segura sem custo".

## Onde a criança está

- **[P]** Um cômodo, o módulo de comando, em panorama com o shader CC0 de falso 3D. Os estados são luz normal, tempestade, abrigo e modo de segurança.
- **[P]** A criança nunca sai da nave (dono e primo, 14/11, para caber no tempo). O lado de fora só aparece pelas câmeras.
- **[P]** De 3 a 4 câmeras para fora (painel solar, rocha, área de amostra, MOXIE). As tarefas de fora são feitas por braço robótico ou rover, como o InSight limpou o painel com a pá.
- **[R]** Os botões ficam fora do espaço distorcido pelo shader: grandes, na faixa vertical central, com no mínimo 24 × 24 px pela WCAG e maiores para criança.
- **[R]** Setas grandes para o pan, porque toque não tem mouse.
- **[P]** Em celular em pé, a página mostra um aviso para deitar o aparelho, em inglês e português, por cima de tudo e desde o carregamento (dono, 14/11). Em pé, o jogo ocupa no máximo um terço da tela em qualquer escala.
- **[P]** Menu inicial antes do sol 1, com o botão Jogar (dono, 14/11). O toque em Jogar pede tela cheia e, em tela cheia, trava a orientação deitada onde o navegador deixa; onde não deixa, vale o aviso. O runtime Web do Godot tem o pedido de tela cheia, mas não a trava, que é uma chamada de JavaScript feita pelo jogo. O turno não pausa em retrato; reavaliar no playtest.

Mapa da sala no turno (dono, 14/11), que substitui o HUD fixo do wireframe. A tela mostra metade do panorama, então o que fica nas pontas só aparece virando, e é isso que dá propósito ao pan:

- **[P]** No centro, a vista de repouso:
  - uma janela larga para Marte, que muda com os eventos (a poeira escurece a vista) e fecha a persiana no estado abrigo;
  - as telas de energia e oxigênio, lado a lado na rampa do console, abaixo da janela.
- **[P]** A vista da janela é um render à parte, com a mesma câmera da sala, posto atrás dela antes do shader: o vidro sai transparente no PNG da sala. Evento novo do lado de fora é só mais uma imagem de vista, sem refazer a sala.
- **[P]** Na esquerda:
  - a porta e o botão do abrigo;
  - a tela do medidor e da margem de radiação;
  - o botão "Perguntar à Terra".
- **[P]** Na direita: os botões das câmeras, por onde se fazem as tarefas de fora, e a estufa da planta.
- **[R]** As barras na sala seguem as regras das barras (ícone, texto e número) e curvam junto com a parede: são desenhadas antes do shader.
- **[P]** No canto superior esquerdo da tela, fixo em qualquer ângulo: as notificações do sol atual, do evento em curso e dos alertas. São só ícones, porque o turno não tem texto para ler, e cumprem o equivalente visual do alarme.
- **[P]** Câmera como no FNAF, sem nenhum asset dele:
  - o botão da câmera faz um monitor portátil subir na hora na lateral direita, numa janela menor que a tela;
  - ele fecha pelo botão "abaixar" ou quando a criança vira para a esquerda;
  - com o monitor aberto, o pan pela borda só funciona do lado oposto a ele.
- **[P]** As posições exatas de cada botão e de cada tela vêm de `assets/comodo/regioes.json`, gerado pelo `arte/blender/comodo.py` a partir da câmera do render.

## Tarefas (minigames)

- **[R]** Toda tarefa mexe numa barra: ou protege um recurso (manutenção), ou gasta energia para render ciência.

| Tarefa | Tipo | Barra | Interação | Base real |
|---|---|---|---|---|
| Limpar o painel | manutenção | Energia | Arrastar a escova do braço sobre a poeira | Poeira derrubou o InSight; a pá do braço limpou um painel |
| Consertar o gerador | manutenção | Oxigênio | Achar a peça certa e encaixar | Filtro entupido e sensor de hidrogênio trocado nos geradores da ISS |
| Montar o abrigo | manutenção | Margem de radiação | Arrastar a carga para as paredes antes do pico | Procedimento da Artemis II |
| Laser do ChemCam | ciência | Energia → ciência | Mirar pontos numa rocha e disparar | 30 pulsos por ponto |
| Selar a amostra | ciência | Energia → ciência | Perfurar, encher o tubo e selar | 43 tubos no Perseverance; a primeira coleta saiu vazia |
| Cultivar planta | ciência | Energia → ciência | Regular luz e água | Veggie e APH na ISS; material da CSA citado no desafio |

- **[P]** As interações e a dificuldade de cada tarefa.
- **[R]** O abrigo custa tempo: no turno em que a tripulação se abriga, não rende ciência. Abrigar cedo demais perde ciência à toa, e tarde demais recebe dose.

## Eventos

- **[R]** Uma tempestade solar e uma tempestade de poeira por missão, mais a poeira que acumula o tempo todo.
- **Tempestade solar** **[R]**:
  - o DONKI prevê a CME chegando a Marte, e o aviso aparece na fase de plano dias antes, numa janela incerta;
  - no turno, o pico de partículas vem de repente, e quem olha o medidor e abriga na hora leva menos dose;
  - base: em maio de 2024 o DONKI previu CMEs em Marte e o Curiosity mediu o maior pico de radiação desde o pouso.
- **Tempestade de poeira** **[R]**:
  - não tem aviso do início, porque não há previsão real;
  - o painel quase para por alguns sóis, e só salva quem guardou energia antes;
  - limpar o painel não resolve, porque a poeira está no céu;
  - base: em 2018 o Opportunity caiu de 645 para 22 Wh e não acordou mais;
  - o sol de início é sorteado entre 2 e 5 a cada missão, e o sorteio se mantém quando o sol recomeça;
  - comportamento-alvo (14/11): numa tempestade de 2 sóis, quem aposta tudo em ciência entra em modo de segurança na maioria dos sorteios, e quem divide passa;
  - **[P]** números de partida: ar inicial para 2 sóis (4, com consumo de 2 por sol), tempestade de 2 sóis com o painel a 10%, aquecimento 1.
- **Poeira acumulando** **[R]**: o painel rende um pouco menos a cada sol, e a tarefa "limpar o painel" devolve.
- **[R]** Explosão solar sem aviso fica fora: sem aviso, não há decisão.

## Atraso de comunicação

- **[R]** Uma mensagem leva de 3 a 22 min por sentido, então a resposta chega no mesmo sol. O atraso pesa nos minutos de uma emergência, em que a tripulação decide sozinha.
- **[P]** Rótulo no aviso ("enviado da Terra há 14 min").
- **[P]** Botão "Perguntar à Terra": a resposta chega depois da ida e volta, na escala do turno.
- **[P]** O medidor da base acusa o pico antes do aviso da Terra.
- **[P]** O detalhe dessa mecânica se fecha com o dono no sábado, como ele pediu.

## Falha e relatório

- **[R]** Não há game over. Quando falta energia para o aquecimento, o oxigênio acaba ou a margem de radiação zera, entra o **modo de segurança**, como o safe mode real: a base corta o não essencial, a tripulação se protege e a ciência para.
- **[R]** Uma tela explica a causa em 1 a 2 frases, com número ou caso real:
  - energia: o Opportunity em 2018;
  - radiação: maio de 2024;
  - oxigênio: cerca de 0,9 kg por pessoa por dia, até um caso confirmado.
- **[R]** Depois do modo de segurança, a saída depende de o sol ter conserto (14/11):
  - se algum plano salva o sol, o botão "o simulador reinicia o sol" volta ao começo da fase de plano do mesmo sol;
  - se nenhum plano salva, porque a causa veio de sóis anteriores (por exemplo, a bateria vazia quando a poeira chegou), o botão vira "seguir em modo de segurança": a base sobrevive com o mínimo, o sol passa sem ciência, conta 1 modo de segurança, e a tela diz que a causa veio antes;
  - o teste de "algum plano salva" é rodar o plano de emergência: tudo ao gerador e abrigo no sol da tempestade solar;
  - o porquê: sem a segunda saída, a criança recomeça um sol impossível sem fim, e o desafio pede aprender com a falha sem punição.
- **[R]** Nada de tela piscando: no máximo 3 flashes por segundo, transição suave e som sempre com equivalente visual.
- **[R]** No fim da missão vem o relatório, o debriefing:
  - ciência, margem final e quantos modos de segurança;
  - uma nota em estrelas, em que cada modo de segurança conta contra;
  - "o que aconteceu de verdade", com a data do caso real.

## Dados

- **[R]** O DONKI vai **embutido e atualizado no build**: um script baixa os últimos 60 dias do CCMC na hora do export, e o jogo mostra a data ("dados do DONKI de 15/11/2026").
- **[R]** Há também a missão histórica de maio de 2024, com o RadLab.
- **[R]** Dado estático nunca aparece como ao vivo (desafio).
- **[P]** As chegadas a Marte que o DONKI prevê na janela de 60 dias costumam já ter passado na hora do build. O simulador reencena a CME real mais recente ("o DONKI previu esta CME chegando a Marte em 13/11; no simulador, ela chega no sol 3") e nunca apresenta a chegada como algo que ainda vai acontecer (dono, 14/11).
- **[R]** O dado vem de `scripts/baixar_donki.py`, que o `scripts/publicar.sh` roda antes do export; o formato está no docstring do script.
- **[R]** Se o filtro de impacto em Marte vier vazio na janela, vale o recorte histórico.
- **[R]** Coleta zero:
  - sem analytics, cookies, login ou chamada a terceiros no código;
  - as fontes vão empacotadas no build;
  - progresso só em localStorage;
  - nenhum IP de criança sai do navegador para a NASA (jogos-educativos-7-a-12-anos (pesquisa no vault do dono)).
- **[R]** A fonte de cada número aparece dentro do jogo (desafio).

## Arte

- **[R]** Render prévio no Blender, um PNG por estado com a mesma câmera, e o jogo em 2D com panorama: [0002](decisoes/0002-a-arte-e-renderizada-antes-no-blender-e-entra-como-panorama-2d.md).
- **[R]** Pixel art em 640×360 e filtro Nearest nas texturas. A resolução interna é fixa; a escala na tela é fracionária (dono, 14/11). Com a escala inteira, o jogo ocupava de 10% a 42% da tela no celular e 26% num notebook de 1366×768 em janela; o custo da fracionária é a borda do pixel levemente suavizada.
- **[R]** Fonte com acentos e licença aberta (Pixeloid, OFL).
- **[R]** Nenhum asset do FNAF nem de fangame.
- **[R]** IA de imagem só para retoque por inpainting, com cada uso no registro-uso-de-si.
- **[R]** A tela de créditos traz as licenças: Godot (MIT), shader (CC0), fonte (OFL) e o Cupcakes Framework (MIT), se for usado.
- **[P]** Câmera do render: a cilíndrica central do Cycles (`CENTRAL_CYLINDRICAL`), com 180° em 1280×360, e o shader de panorama com `zoom` = (1 − cos(metade do ângulo da janela)) / 0,0015, que dá 195 para a janela de 640 px. A perspectiva não serve: o shader curva o que ela já deixa reto, e em 1280 px ela não alcança a porta do abrigo na parede lateral. Medido no protótipo de 14/11 (`arte/blender/comparar_camera.py` no repo).

## Ordem de construção e de corte

- **P0, o jogo inteiro e mínimo (sábado):**
  - export Web vazio no ar na primeira hora, testado na máquina do playtest (risco do WASM SIMD em máquina velha);
  - um cômodo com arte provisória;
  - a fase de plano com as três barras;
  - avançar sol, modo de segurança e relatório;
  - a tempestade solar com o dado embutido;
  - a tarefa do abrigo.
- **P1, o que dá o desenho (sábado à noite e domingo de manhã):**
  - tempestade de poeira e limpar o painel;
  - consertar o gerador;
  - ChemCam;
  - sol 1 guiado;
  - menu inicial com o botão Jogar;
  - português e inglês;
  - arte final.
- **P2, se sobrar:** amostra, planta, "Perguntar à Terra" e estática nas câmeras.

Se atrasar, corta-se nesta ordem: planta → amostra → Perguntar à Terra → estática. O P0 nunca se corta.

O código congela no domingo, horas antes do fim do evento, para sobrar tempo para o vídeo de 30 s e o formulário.

## Playtest

Se houver criança acessível no domingo, faz-se um playtest de 15 min pelo roteiro da pesquisa de jogos educativos (pesquisa no vault do dono):
- consentimento do responsável e assentimento da criança;
- direito de parar;
- anotação em papel sem nome, nada gravado.

Nome, voz e imagem de menor ficam fora da submissão.

## Em aberto

- Quem faz o quê. O dono ainda não quer fechar as funções. Rascunho:
  - o primo faz as cenas, o loop, as barras, as tarefas, o shader e o ajuste dos números;
  - o dono faz a arte, o script do DONKI, os textos com fonte, o deploy, a submissão e os créditos.
- O detalhe do atraso de comunicação e do "Perguntar à Terra", a fechar com o dono.

## O que não faz (propostas recusadas)

- Lua como cenário: [0001](decisoes/0001-o-posto-do-jogo-fica-em-marte-nao-na-lua.md).
- Blindagem como barra que acaba: não corresponde a nada físico. O recurso é a margem de radiação, e o abrigo é a ação.
- Escudo que gasta energia: não tem respaldo no que a NASA faz, e o abrigo custa tempo.
- Gerador de oxigênio a partir de água: exigiria uma 4ª barra.
- Tempo real contínuo como no FNAF: obrigaria a ler sob relógio.
- Game over, morte, jumpscare, terror e humor sombrio.
- Nome "Five Nights at Mars" ou "Mars Shift".
- DONKI ao vivo do navegador: mandaria o IP da criança à NASA e dependeria do Wi-Fi.
- itch.io: Google Analytics e cookies na página do jogo.
- 3D ao vivo no Godot e IA de imagem para gerar os estados: [0002](decisoes/0002-a-arte-e-renderizada-antes-no-blender-e-entra-como-panorama-2d.md).
- A resposta da Terra "só no sol seguinte": a ida e volta cabe no mesmo sol.
