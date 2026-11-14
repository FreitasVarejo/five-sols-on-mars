> Cópia do vault do dono em 14/11/2026 17:15. Não edite aqui: proponha a mudança ao dono, que atualiza a fonte e recopia.

# Five Sols on Mars

O jogo do time para o desafio Junior Astronaut Mission Trainer. Voltar para nasa-spaceapps-26. Os termos estão no [glossário](glossario.md).

Desenho fechado pelo dono em 13/11/2026, antes do hackathon, como base para o primo, que fica com o game design e a programação. Cada item leva uma marca:
- **[R] restrição:** vem do desafio, do dado, da pesquisa ou do regulamento, e não muda sem reabrir a fonte;
- **[P] proposta:** o primo pode trocar no sábado.

Nada de código, cena nem asset antes de 14/11 (regulamento).

Wireframe das telas (14/11): https://claude.ai/artifact/QotyJYnZuz6gMMqdJPpPHE. As marcas R e P dele seguem esta spec; W é escolha do wireframe, que o primo troca livremente. O turno do wireframe ainda mostra o HUD fixo; o mapa da sala em "Onde a criança está" vale acima dele. O wireframe também é anterior ao terminal, aos cards da Terra e ao fim do sol (14/11, à tarde), e nisso esta spec vale acima dele.

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
- **[P]** O tutorial do sol 1 é um roteiro gravado que a Terra manda no pacote da manhã. A base mostra um passo por vez, conforme a criança termina o anterior, porque com o atraso a Terra não vê o clique.
- Cada sol tem duas fases e o fim do sol:
  - **[R] Fase de plano**, sem relógio. A criança lê o aviso do clima espacial e os pedidos da Terra, divide a energia entre oxigênio, tarefas de ciência e bateria, e vê o efeito previsto de cada escolha antes de confirmar.
  - **[R] Fase de turno**, curta e em tempo real, só clique e sem texto para ler. Aparecem as tarefas de ciência escolhidas no plano mais as tarefas de manutenção que a base pede, numa lista como a do Among Us.
  - **[R] Fim do sol**, sem relógio: o diário do sol e o envio à Terra.
- **[R]** Todo texto mora fora do turno: no plano e no fim do sol.
- **[P]** O plano acontece dentro do terminal, aberto em tela cheia.
- **[R]** A tela do plano é uma só e enxuta, porque a primeira versão jogável (P0, 14/11) chegou a 36 linhas, 103 palavras e 53 números numa tela, com o mesmo número repetido até três vezes. Abas no plano não servem: o terminal já tem as 4 abas do limite, e o efeito previsto precisa ficar ao lado do controle. As regras:
  - cada número aparece uma vez, e as barras mostram "antes → depois";
  - ficam na tela os dois controles (oxigênio e ciência), as três barras com a previsão e o botão "Confirmar plano";
  - ficam também, porque são restrição: a linha fixa do aquecimento da noite, o aviso do excedente que se perde com a bateria cheia (é o custo de guardar) e "ar para N sóis" na barra de oxigênio (a troca entre reserva de oxigênio e pesquisa);
  - a conta da energia (bateria + painel − aquecimento) e o detalhe do tanque vão para a aba fontes do terminal;
  - o card da Terra abre por cima do plano, a criança lê e fecha, e ele sai do plano. A data do DONKI fica no card do aviso, não só nas fontes, porque dado estático nunca parece ao vivo.
- **[P]** No sol 1 guiado, o plano vem em passos, uma decisão por tela: a mensagem, o oxigênio, a ciência e o resumo com "Confirmar plano". Nos sóis 2 a 5, a tela única, porque separar oxigênio e ciência esconderia a troca entre eles.
- **[P]** O turno dura de 60 a 90 s, com 1 s = 1 min de tempo real.
- **[P]** O que encerra o turno:
  - o relógio, que começa em "Confirmar plano". O Sol andando no céu é esse relógio desenhado: na faixa do Sol, na janela (dia, pôr do Sol, escuro) e na luz da sala, que esquenta nos últimos ~10 s sem piscar. Quando o Sol se põe, o turno acaba sozinho;
  - ou a criança, pelo botão "Encerrar o sol", que só aparece quando todas as tarefas da lista acabaram;
  - o modo de segurança no meio do turno também encerra o turno ali.
- **[P]** O pico de um evento é sorteado só até ~70% do turno, para nunca coincidir com o pôr do Sol.
- **[P]** No sol 1, o Sol fica parado enquanto o card do tutorial espera o passo da criança.
- **[P]** Fim do sol:
  - o diário do sol se escreve sozinho: o que aconteceu, as barras antes e depois, a ciência, as mensagens recebidas e a consequência da manutenção não feita;
  - a criança lê e aperta "Enviar à Terra";
  - vem a noite, numa transição curta, e o aquecimento sai da bateria;
  - o pacote da Terra da manhã abre o plano do sol seguinte.

  Base: o rover manda os dados à Terra num contato à tarde e recebe o plano de manhã; no MDRS, a tripulação manda um relatório por sol (comunicacao-com-atraso-terra-marte (pesquisa no vault do dono), terminais-de-tripulacao (pesquisa no vault do dono)).
- **[P]** A história anda por três botões, sempre o mesmo gesto: "Confirmar plano", "Encerrar o sol" (opcional) e "Enviar à Terra".
- **[R]** Um evento por vez. A crise permanente cansa, e a Innersloth a tirou do Among Us (referencias-de-jogos-de-gestao (pesquisa no vault do dono)).
- **[R]** Critério da calibração (14/11): nenhuma estratégia pode ser melhor ou igual às outras duas em ciência e em modos de segurança em todos os cenários. Uma estratégia cautelosa demais pode sair perdendo: cautela que custa caro também é lição, e não viola "nenhuma escolha segura sem custo".

## Onde a criança está

- **[P]** Um cômodo, o módulo de comando, em panorama com o shader CC0 de falso 3D. Os estados são luz normal, tempestade, abrigo e modo de segurança.
- **[P]** A criança nunca sai da nave (dono e primo, 14/11, para caber no tempo). O lado de fora só aparece pelas câmeras.
- **[P]** As câmeras para fora abrem só pelo terminal: painel solar, rocha, MOXIE e visão geral, mais uma do céu, apontada para o Sol, onde se vê a poeira escurecer o céu. Cada câmera custa um render por clima (normal e poeira). As tarefas de fora são feitas por braço robótico ou rover, como o InSight limpou o painel com a pá.
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
  - a tela de comunicação com a Terra, no lugar do antigo botão azul (ver "Comunicação com a Terra").
- **[P]** Na direita, a parede da ciência de dentro, em destaque: a estufa (cultivar planta) e a glovebox (selar a amostra).
- **[R]** As barras na sala seguem as regras das barras (ícone, texto e número) e curvam junto com a parede: são desenhadas antes do shader.
- **[P]** No canto superior esquerdo da tela, fixo em qualquer ângulo: as notificações do sol atual, do evento em curso e dos alertas. São só ícones, porque o turno não tem texto para ler, e cumprem o equivalente visual do alarme.
- **[P]** As posições exatas de cada botão e de cada tela vêm de `assets/comodo/regioes.json`, gerado pelo `arte/blender/comodo.py` a partir da câmera do render.

## Terminal

O computador da base, que reúne o que a criança consulta e faz pela tela. Base: terminais-de-tripulacao (pesquisa no vault do dono).

- **[P]** Um botão único, fixo embaixo da tela, faz o terminal subir na hora, como camada de tela por cima do panorama, sem a curva do shader. O mesmo botão o abaixa. Atrás dele fica o que a criança estava olhando, que muda com o pan.
- **[P]** Abas:
  - **câmeras**, escolhidas num mapa de Gale, com sobreposição de alvo e telemetria, como as vistas da estação robótica da ISS;
  - **tarefas**, a lista do turno;
  - **diário**, o registro do que passou: os diários dos sóis anteriores e as mensagens da Terra que já venceram;
  - **fontes**, com o número, a fonte e a data do DONKI, mais o detalhe que sai do plano: a conta da energia e o tanque de O2. Atende à regra de que a fonte de cada número aparece no jogo.
- **[R]** No máximo 4 abas e nenhuma sub-aba, porque a tela leva só o necessário e a navegação é rasa (NASA-STD-3001 [V2 10040] e [V2 10043]).
- **[P]** As abas são teclas grandes na moldura, como as bezel keys das telas da Orion.
- **[R]** Cores: verde só no que se clica, como na Orion; vermelho e amarelo só em alerta (NASA-STD-3001 [V2 10118] e [V2 10119]); azul só no que vem da Terra.
- **[R]** O terminal não guarda as ordens da Terra que ainda valem: elas ficam na tela de comunicação. Quando vencem, vão para o diário.
- **[P]** O tamanho do terminal e se o pan funciona com ele aberto ficam com o primo.

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
- **[P]** Onde cada tarefa se faz: painel, gerador (MOXIE) e ChemCam pelas câmeras do terminal; amostra na glovebox e planta na estufa, na parede direita; abrigo na porta da esquerda.
- **[R]** O abrigo custa tempo: no turno em que a tripulação se abriga, não rende ciência. Abrigar cedo demais perde ciência à toa, e tarde demais recebe dose.
- **[R]** Tarefa de ciência não feita até o fim do turno: o plano só reserva a energia, e a tarefa a gasta quando roda, como o instrumento real só gasta quando liga. A reserva da tarefa não feita volta à bateria, respeitando o teto (o excedente se perde).
  - O porquê: perder a energia puniria a habilidade motora em vez da escolha, e faria o abrigo custar energia, não só tempo.
  - Consequência para a calibração: ela supõe toda tarefa escolhida feita, então vale como teto.
- **[R]** Tarefa de manutenção não feita: a consequência vem pela própria barra, e a tarefa continua na lista no sol seguinte. O diário registra a consequência antes de ela pesar.
  - painel sujo rende menos no sol seguinte;
  - gerador quebrado produz zero O2. O plano mostra "gerador quebrado: 0 O2, conserte no turno";
  - abrigo não montado recebe a dose no próprio turno.
- **[P]** O conserto do gerador no turno libera a produção de O2 do mesmo sol.
- **[R]** Pedido de ciência da Terra não feito vence no fim do sol e vai para o diário.

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

## Comunicação com a Terra

Base: comunicacao-com-atraso-terra-marte (pesquisa no vault do dono).

- **[R]** Uma mensagem leva de 3 a 22 min por sentido, e pergunta e resposta levam no mínimo o dobro. O atraso pesa nos minutos de uma emergência, em que a tripulação decide sozinha.
- **[R]** A comunicação é de mão única e sem conversa: a Terra manda pacotes e avisos, e a base relata no diário. Não há assistente de IA a bordo. Nos análogos, a comunicação com atraso é mensagem gravada ou escrita, e o atraso aumenta a autonomia da tripulação; é a independência que o jogo quer dar à criança.
- **[R]** A Terra pede ciência, com o valor de cada pedido, e a criança escolhe o que aceitar no plano. A manutenção quem pede é a própria base, pelos sensores.
- **[P]** A **tela de comunicação** fica na parede esquerda, no lugar do antigo botão azul. Ela acende quando chega mensagem (no máximo 3 flashes por segundo) e guarda as ordens ativas.
- **[P]** As mensagens aparecem como **cards azuis**, como os tutoriais de jogo de celular:
  - o card nasce da tela de comunicação, ou entra pela borda esquerda se ela estiver fora da vista, e pode apontar e destacar qualquer lugar da tela;
  - o card mora na camada de tela, depois do shader, para não curvar nem sumir com o pan. Para apontar um alvo da sala, ele calcula onde o alvo está agora, a partir de `regioes.json` passado pela mesma conta do shader. Se o alvo está fora da vista, ele aponta para a seta do pan;
  - no plano e no fim do sol, o card tem texto e pode escurecer o resto da tela e travar até a criança fazer o passo;
  - no turno, o card leva só ícone e "há N min", não escurece nem trava nada, e nunca cobre o medidor nem as barras (exceção: o sol 1, em que o Sol para enquanto o card espera);
  - fechado, o card volta para a tela de comunicação como ordem ativa. Quando a ordem vence, vai para o diário do terminal.
- **[P]** Rótulo no card: "enviado da Terra há 14 min".
- **[P]** O medidor da base acusa o pico antes do aviso da Terra. Com 1 s = 1 min, o card do pico chega de 3 a 22 s depois do medidor, e quem espera a Terra leva mais dose.

## Falha e relatório

- **[R]** Não há game over. Quando falta energia para o aquecimento, o oxigênio acaba ou a margem de radiação zera, entra o **modo de segurança**, como o safe mode real: a base corta o não essencial, a tripulação se protege e a ciência para.
- **[R]** Uma tela explica a causa em 1 a 2 frases, com número ou caso real:
  - energia: o Opportunity em 2018;
  - radiação: maio de 2024;
  - oxigênio: cerca de 0,9 kg por pessoa por dia, até um caso confirmado.
- **[R]** Depois do modo de segurança, a saída depende de o sol ter conserto (14/11):
  - se algum plano salva o sol, o botão "o simulador reinicia o sol" volta ao começo da fase de plano do mesmo sol;
  - se nenhum plano salva, porque a causa veio de sóis anteriores (por exemplo, a bateria vazia quando a poeira chegou), o botão vira "seguir em modo de segurança": a base sobrevive com o mínimo, o sol passa sem ciência, conta 1 modo de segurança, e a tela diz que a causa veio antes;
  - o teste de "algum plano salva" é rodar o plano de emergência: tudo ao gerador, consertar o que estiver quebrado e abrigo no sol da tempestade solar. Sem o conserto no teste, o gerador quebrado daria zero e mandaria para "seguir em modo de segurança" um sol que tinha salvação;
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
  - o terminal com o botão único e a fase de plano dentro dele, com as três barras;
  - o fim do turno pelo relógio, um diário mínimo com "Enviar à Terra", modo de segurança e relatório;
  - a tempestade solar com o dado embutido, com o aviso da Terra num card azul simples;
  - a tarefa do abrigo.
- **P1, o que dá o desenho (sábado à noite e domingo de manhã):**
  - primeiro, o plano enxuto, o card por cima do plano e as 4 abas do terminal, com a de fontes já preenchida (o plano enxuto depende dela);
  - o conteúdo das abas de câmeras e de tarefas;
  - tempestade de poeira e limpar o painel;
  - consertar o gerador;
  - ChemCam;
  - os cards azuis com destaque e a tela de comunicação;
  - sol 1 guiado, com o plano em passos;
  - o diário completo;
  - "Encerrar o sol" e a sala acompanhando o pôr do Sol;
  - menu inicial com o botão Jogar;
  - português e inglês;
  - arte final.
- **P2, se sobrar:** amostra na glovebox, planta na estufa, câmera do céu e estática nas câmeras.

Se atrasar, corta-se nesta ordem: planta → amostra → câmera do céu → estática. O P0 nunca se corta.

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
- A cor do pôr do Sol em Marte (azulada nas fotos dos rovers): conferir a fonte antes de entrar no jogo.
## O que não faz (propostas recusadas)

- Plano dividido em abas: o terminal já tem as 4 abas do limite, e o efeito previsto sairia de perto do controle.
- Plano em passos nos sóis 2 a 5: separar oxigênio e ciência esconderia a troca entre eles, que é a lição do jogo. Fica só no sol 1.
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
- Botão "Perguntar à Terra" e qualquer conversa com a Terra: pergunta e resposta levam no mínimo o dobro do atraso, os análogos usam mensagem gravada, e a mão única dá à criança a independência que o atraso real impõe. Por isso a variante "a resposta só no sol seguinte" também saiu.
- Assistente de IA a bordo: existe só como experimento (o CIMON na ISS, o assistente médico NASA/Google em prova de conceito), não como retrato de hoje (comunicacao-com-atraso-terra-marte (pesquisa no vault do dono)).
- A Terra designar as tarefas: tiraria a escolha com custo. A Terra pede, e a criança escolhe.
- Energia de ciência perdida quando a tarefa não é feita: puniria a habilidade motora em vez da escolha e faria o abrigo custar energia.
- Monitor das câmeras subindo como no FNAF e os 4 botões de câmera na parede direita: substituídos pelo terminal.
