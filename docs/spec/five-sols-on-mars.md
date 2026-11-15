> Cópia do vault do dono em 15/11/2026 16:38. Não edite aqui: proponha a mudança ao dono, que atualiza a fonte e recopia.

# Five Sols on Mars

O jogo do time para o desafio Junior Astronaut Mission Trainer. Voltar para nasa-spaceapps-26. Os termos estão no [glossário](glossario.md).

Desenho fechado pelo dono em 13/11/2026, antes do hackathon, como base para o primo, que fica com o game design e a programação. Cada item leva uma marca:
- **[R] restrição:** vem do desafio, do dado, da pesquisa ou do regulamento, e não muda sem reabrir a fonte;
- **[P] proposta:** o primo pode trocar no sábado.

Nada de código, cena nem asset antes de 14/11 (regulamento).

Wireframe das telas (14/11): https://claude.ai/artifact/QotyJYnZuz6gMMqdJPpPHE. As marcas R e P dele seguem esta spec; W é escolha do wireframe, que o primo troca livremente. O turno do wireframe ainda mostra o HUD fixo; o mapa da sala em "Onde a criança está" vale acima dele. O wireframe também é anterior ao terminal, aos cards da Terra e ao fim do sol (14/11, à tarde), e nisso esta spec vale acima dele.

## O jogo

Uma criança de 7 a 12 anos comanda por 5 sóis um posto na cratera Gale, em Marte, de dentro do módulo de comando. Ela divide a energia, faz tarefas de uma tela e se protege das tempestades do Sol e da poeira. Sai sabendo que toda escolha tem custo. É um **treinador de missão**: a falha leva ao modo de segurança, sem game over, e o fim da missão é um debriefing.

- **[P]** A nave é a moldura dos 5 sóis (dono, 14/11): a base precisa aguentar até a nave chegar, no fim do sol 5, e a nave leva a ciência para a Terra. O objetivo aparece na abertura: "Keep the base alive. Send science home." / "Mantenha a base viva. Mande ciência para casa." O porquê: com "aguente até a nave chegar" sozinho, quem só sobrevive cumpria o objetivo com 0 de ciência.
- **[R]** Marte, não a Lua: [0001](decisoes/0001-o-posto-do-jogo-fica-em-marte-nao-na-lua.md).
- **[R]** Navegador, sem download e sem conta (desafio). Godot 4.7.2 com renderer Compatibility e export Web single-threaded (godot-primeira-pessoa-pixel-art (pesquisa no vault do dono)).
- **[R]** No ar no GitHub Pages (github-pages-e-coleta-zero (pesquisa no vault do dono)).
- **[P]** Nome: Five Sols on Mars (nome-do-jogo (pesquisa no vault do dono)).
- **[R]** Inglês por padrão e português com seletor, com as strings numa tabela CSV desde a primeira hora. O seletor fica na tela, e `?lang=` vale por cima dele (dono, 14/11). O P0 só trocava de idioma pela URL.
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
  - o oxigênio custa de 8 a 12 kWh/kg num MOXIE em escala real (inferência sobre números da NASA; a escala real foi pensada para o propelente de volta, e o MOXIE de verdade fez cerca de 10,5 g/h). Na tela: "uma versão gigante do MOXIE, que ainda não existe";
  - em 20/05/2024, a dose do dia no Curiosity foi cerca de 17 vezes a média dos cinco dias anteriores (69,3 contra 4,1), com pico cerca de 74 vezes (304), pelo RadLab. É a média das amostras do dia, conta do time: o RadLab traz mais amostras em 20 e 21/05 (139 e 108, contra 82 a 84 nos outros dias), então a submissão diz "average reading", e não "dose of the day" (revisão de 15/11). Na tela: "a leitura de radiação do Curiosity saltou de cerca de 4 para cerca de 300 no pico", sem unidade, porque a unidade que o RadLab documenta não fecha com os 8.100 µGy do release do JPL. Não usar "triplicou", que compara a véspera com o dia seguinte ao pico;
  - a NASA projeta a proteção para que o evento solar de referência (a soma dos eventos de outubro de 1989) dê menos de 250 mSv (NASA-STD-3001 Vol. 1 Rev C, V1 4031). Não é teto de cada evento.
- **[R]** A escala da radiação (dono, 14/11). Na margem, a tempestade solar vale de 15 a 20 sóis normais, pela razão de 20/05/2024. Só o fundo não zera a margem nos 5 sóis. A escala é ampliada: na realidade, 5 sóis em Gale dão menos de 1,5% do limite, e o pico de maio de 2024 ficou em cerca de 3% de 250 mGy. A tela diz que, no jogo, cada sol vale muitos dias de radiação de verdade. No jogo, o abrigo deixa passar 1/5 da dose da tempestade; a simulação da Orion para o evento de outubro de 1989 dá cerca de 1/4 (George et al., Nature, 2024, em dados-nasa-do-junior-astronaut (pesquisa no vault do dono)), e a aba fontes mostra os dois números.

  Fontes: recursos-de-habitat-lunar-e-marciano (pesquisa no vault do dono) e dados-nasa-do-junior-astronaut (pesquisa no vault do dono).
- **[P]** Os números do jogo, os máximos e os limiares das estrelas são do primo. A [página de calibração](https://claude.ai/artifact/BbJQ9PyK6rhk4C3jKahBzE) simula os 5 sóis com três estratégias (tudo em ciência, equilibrada, conservadora) em todos os sóis de início da poeira e avisa quando uma domina. Ela ainda usa a razão antiga de 3 entre a tempestade e o sol normal, anterior à escala de 14/11.

A troca com custo, decidida pelo dono em 14/11:

- **[R]** A energia que sobra do plano vai sozinha para a bateria. Guardar custa a ciência que não se fez, e não há controle "guardar".
- **[R]** A bateria tem teto, e o excedente se perde. **[P]** O valor, calibrado para que o teto não seja o que decide o jogo.
- **[R]** O O2 produzido a mais fica no tanque, até o máximo dele: é a troca "reserva de oxigênio por pesquisa" das perguntas-guia do desafio.
- **[R]** O **aquecimento da noite** sai da energia todo sol, antes do plano e sem escolha. É uma linha fixa na fase de plano, não uma 4ª barra. É o que dá à bateria função própria na tempestade de poeira, porque o tanque de O2 sozinho não cobre o aquecimento. Base: o Opportunity em 2018 e o InSight em 2022 pararam sem energia. Os releases do JPL não falam em aquecedores: o aquecimento da noite é simplificação do jogo, e a tela diz "ficou sem energia". **[P]** O valor; o de partida é 1 contra 8 do painel.

## Missão e sol

- **[R]** A missão principal tem 5 sóis e é determinística: as mesmas ações dão sempre o mesmo resultado. O sol de cada evento, o instante do pico e o sol da quebra do gerador são fixos, e o sorteio só começa no freeplay (dono, 14/11; ver "Freeplay"). O porquê: o jurado, a criança do playtest e o vídeo de 30 s veem a mesma missão, e a calibração mede um cenário só. A decisão é do começo da tarde de 14/11 e só chegou a esta spec à noite; o P0 foi programado com sorteio.
- **[R]** A agenda da missão (dono, 14/11): o sol 1 é guiado e não tem evento; a tempestade solar cai no sol 2; a tempestade de poeira cobre os sóis 3 e 4; o sol 5 é de recuperação, e no fim dele a nave chega. **[P]** O gerador quebra no sol 5, a única posição que mantém um evento por sol (dono, 14/11); o roteiro da tarde o punha no sol 3, e a posição não muda nenhum número (medido em 14/11).
- **[R]** Antes do freeplay, a criança vê todas as features e todos os tutoriais do jogo; o freeplay só recombina o que a missão mostrou (dono, 14/11).
- **[P]** Um adulto fecha os 5 sóis em cerca de 10 min. Não é teto rígido: o que pesa é o tempo que o jurado leva para chegar ao relatório (dono, 14/11).
- **[P]** Roteiro por sol (dono, 14/11): a primeira vez de cada coisa é pedida pelo controle da missão, no sol em que ela aparece, e o sol 1 traz um treino de emergência, para que o modo de segurança seja visto também por quem joga bem.
- **[R]** O sol 1 é guiado, um passo por vez, sem evento. Do 2º ao 5º ano, instruir antes funciona melhor que deixar tentar (jogos-educativos-7-a-12-anos (pesquisa no vault do dono)).
- **[P]** O tutorial do sol 1 é um roteiro gravado que a Terra manda no pacote da manhã. A base mostra um passo por vez, conforme a criança termina o anterior, porque com o atraso a Terra não vê o clique.
- **[P]** Para a entrega, o sol 1 guiado sai na versão mínima, com o card azul que já existe (dono, 14/11): três cards no plano do sol 1 (o que é um sol e o objetivo; o oxigênio; a ciência) e um no primeiro turno (onde ficam as tarefas, o botão do abrigo e a porta do dormitório). O card do turno diz cada lugar (dono, 15/11): o ChemCam no Terminal, Planta e Amostra na parede direita, o abrigo e o dormitório à esquerda, e as setas para virar a sala. O porquê: Planta e Amostra só começam na estufa e na glovebox, fora da vista de repouso, e no Terminal aparecem sem botão. O porquê: o P0 não ensina nada, a vista de repouso do turno não tem nada clicável, e a versão em passos disputa o P1 inteiro.
- **[P]** A abertura (dono, 15/11): antes do sol 1, uma tela que rola para baixo, como a do A.T.L.A.S., em oito quadros com os renders do jogo: onde a criança está (a cratera Gale, e ela é a comandante), a tripulação e o que é um sol, para que servem o oxigênio, a energia, a radiação e a ciência, a progressão (5 sóis, a nave, o modo livre; "cada sol: planejar, trabalhar, relatar") e o objetivo, com "Começar a missão". Os textos, em inglês e português, com no máximo 8 palavras por frase, estão no protótipo: https://claude.ai/artifact/Mrs5Kb8H5cWqYpK27RK2RP. O porquê: o feedback de 15/11 de um ex-colega do A.T.L.A.S.; a criança não sabia para que serve cada barra nem o que vem depois do sol 5.
  - a linha do tempo não mostra os eventos: cada um se apresenta no sol em que chega (dono, 15/11);
  - o quadro da radiação não fala do abrigo: quem o apresenta é o card do sol 2 (dono, 15/11);
  - com a abertura explicando o porquê, os três cards do plano do sol 1 passam a só apontar: o controle do oxigênio, o da ciência, e as barras com "Confirmar plano" (dono, 15/11);
  - o card das barras também diz que a energia que sobra fica na bateria (dono, 15/11). O porquê: guardar energia é a lição da poeira, e nenhum texto de tela dizia como se guarda;
  - os termos da tela (dono, 15/11): "gerador de oxigênio" em todo lugar, no lugar de "máquina de oxigênio" no card da quebra; a abertura explica a margem ("Margem é quanto a tripulação ainda aguenta. Ela nunca enche de novo."); em português, "Você comanda a missão.", sem gênero; e, no inglês, "energy" também nas causas, nunca "power";
  - na tela, o freeplay se chama "Free play" / "Modo livre" (dono, 15/11), e o botão do relatório que abre a versão zero leva esse nome;
  - os cards da primeira vez da poeira (sol 3) e do gerador quebrado (sol 5) entram na entrega, no plano do sol em que o evento começa (dono, 15/11). O resto do roteiro por sol, com o treino de emergência, segue para depois da entrega.
  - O que implementar, com os textos e as chaves: briefing-abertura.
- **[P]** Antes do primeiro quadro da abertura, a viagem Terra → Marte da versão do primo (`LoadingView`): o foguete na órbita, o registro da missão passo a passo e o pouso; pula-se com um toque (dono, 15/11). Vem em 640×360, com os textos no CSV, sem as dicas que trocavam sozinhas (texto com tempo limite) e com a viagem real do Curiosity, que pousou em Gale (254 dias, de 26/11/2011 a 06/08/2012), no lugar dos números inventados. O porquê: a peça é trabalho do primo, e a viagem que termina no pouso leva direto a "Mars. Gale Crater.". O som é um ronco na ignição e um baque no pouso, sintetizados por script do time como o alarme, sem amostra de terceiros (dono, 15/11).
- **[P]** Cada sol da missão fixa abre com a tela de introdução do sol da versão do primo (`IntroView`), antes do plano e dos cards (dono, 15/11). Ela espera o "Continuar". No Modo livre ela não aparece, porque a história é só da missão fixa.
  - À direita fica a página de diário em papel, com a história daquele sol. A mesma frase continua no diário do fim do sol, como registro (dono, 15/11): a página é o momento, o diário guarda.
  - Nos sóis 2, 3 e 5, a página também traz uma pista, vaga, na voz do diário: o Sol agitado, o horizonte marrom e o barulho no gerador de oxigênio. O porquê: é a mecânica do diário de que o primo mais gosta (15/11, 10:25). E não muda o balanço, porque o card da Terra conta o mesmo evento no plano do mesmo sol, segundos depois. Não há pista falsa na missão fixa.
  - À esquerda: o relógio chegando a 06:00, "SOL N", a cratera Gale e a checklist dos sistemas (pressurização, gerador de oxigênio, painel solar, contato com a Terra). O item do gerador fica em alerta no sol da quebra, e o do painel nos sóis de poeira, quando o estado do começo do plano já mostra o problema.
  - Ficam para depois da entrega: as pesquisas do dia com bônus da página dele, que são os pedidos da Terra com valor que esta spec já pede e o jogo ainda não tem, e a pista falsa.
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
  - o relógio, que começa em "Confirmar plano". O Sol andando no céu é esse relógio desenhado: na faixa do Sol, na janela (dia, pôr do Sol, escuro) e na luz da sala, que fica azulada nos últimos ~10 s sem piscar, como o pôr do Sol em Gale (Curiosity, sol 956). Quando o Sol se põe, o turno acaba sozinho;
  - ou a criança, indo dormir pela porta do dormitório (ver "Onde a criança está"), que só acende quando todas as tarefas da lista acabaram;
  - o modo de segurança no meio do turno também encerra o turno ali.
- **[P]** O pico de um evento cai até ~70% do turno, para nunca coincidir com o pôr do Sol. Na missão o instante é fixo; no freeplay, sorteado. Com o turno de 60 s, a estratégia equilibrada faz 5 de ciência com o pico aos 25 s e 4 com o pico aos 15 s (medido em 14/11).
- **[P]** No sol 1, o Sol fica parado enquanto o card do tutorial espera o passo da criança.
- **[P]** Fim do sol:
  - o diário do sol se escreve sozinho: o que aconteceu, as barras antes e depois, a ciência, as mensagens recebidas e a consequência da manutenção não feita;
  - a criança lê e aperta "Enviar à Terra";
  - vem a noite, numa transição curta, e o aquecimento sai da bateria;
  - o pacote da Terra da manhã abre o plano do sol seguinte.

  Base: o rover manda os dados à Terra num contato à tarde e recebe o plano de manhã; no MDRS, a tripulação manda um relatório por sol (comunicacao-com-atraso-terra-marte (pesquisa no vault do dono), terminais-de-tripulacao (pesquisa no vault do dono)).
- **[P]** A história anda por três gestos: "Confirmar plano", ir dormir pela porta (opcional) e "Enviar à Terra" (dono, 14/11).
- **[R]** Um evento por vez. A crise permanente cansa, e a Innersloth a tirou do Among Us (referencias-de-jogos-de-gestao (pesquisa no vault do dono)). Vale à risca na missão, pela agenda (um evento por sol), e no sorteio do freeplay (dono, 14/11). O P0 sorteava a tempestade solar e a poeira sem um olhar o outro, e as duas caíam no mesmo sol em 12 de 24 sorteios.
- **[R]** Critério da calibração (14/11): nenhuma estratégia pode ser melhor ou igual às outras duas em ciência e em modos de segurança em todos os cenários. Uma estratégia cautelosa demais pode sair perdendo: cautela que custa caro também é lição, e não viola "nenhuma escolha segura sem custo". Na missão há um cenário só, e o critério vira a fronteira entre ciência e modos de segurança nesse cenário (com os números do P0, 7 de ciência sem nenhum modo contra 9 com um); "em todos os cenários" vale para os sorteios do freeplay (dono, 14/11).

## Onde a criança está

- **[P]** Um cômodo, o módulo de comando, em panorama com o shader CC0 de falso 3D. Os estados são luz normal, tempestade, abrigo e modo de segurança.
- **[P]** A criança nunca sai da nave (dono e primo, 14/11, para caber no tempo). O lado de fora só aparece pelas câmeras.
- **[P]** As câmeras para fora abrem só pelo terminal: painel solar, rocha, MOXIE e visão geral, mais uma do céu, apontada para o Sol, onde se vê a poeira escurecer o céu. Cada câmera custa um render por clima (normal e poeira). As tarefas de fora são feitas por braço robótico ou rover, como o braço do InSight, que em 2021 soltou areia ao vento para tirar parte da poeira de um painel.
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
  - na ponta, a porta do dormitório: tocá-la encerra o sol (ir dormir). Ela só se clica quando o turno pode acabar, e então a lâmpada verde dela acende e uma lua aparece por cima (dono, 14/11);
  - o botão do abrigo, ao lado da porta;
  - a tela do medidor e da margem de radiação;
  - a tela de comunicação com a Terra, no lugar do antigo botão azul (ver "Comunicação com a Terra").
- **[P]** Na direita, a parede da ciência de dentro, em destaque: a estufa (cultivar planta) e a glovebox (selar a amostra).
- **[R]** As barras na sala seguem as regras das barras (ícone, texto e número) e curvam junto com a parede: são desenhadas antes do shader.
- **[P]** No canto superior esquerdo da tela, fixo em qualquer ângulo: as notificações do sol atual, do evento em curso, dos alertas e a lua de "pode dormir", porque a porta do dormitório fica na ponta e só aparece virando (dono, 14/11). São só ícones, porque o turno não tem texto para ler, e cumprem o equivalente visual do alarme.
- **[P]** As posições exatas de cada botão e de cada tela vêm de `assets/comodo/regioes.json`, gerado pelo `arte/blender/comodo.py` a partir da câmera do render.
- **[P]** O que puder morar na sala sai do terminal, para espalhar a carga de atenção pela vista; o terminal fica com o que precisa de texto (dono, 14/11).

## Terminal

O computador da base, que reúne o que a criança consulta e faz pela tela. Base: terminais-de-tripulacao (pesquisa no vault do dono).

- **[P]** Na tela, o terminal se chama "Panel" / "Painel", o nome do painel do primo, e o botão de baixo leva as setas dele: ▲ com o painel embaixo e ▼ com ele no alto (dono, 15/11). Nesta spec e no código, o nome continua "terminal".

- **[P]** Um botão único, fixo embaixo da tela, faz o terminal subir, como camada de tela por cima do panorama, sem a curva do shader. O mesmo botão o abaixa. Atrás dele fica o que a criança estava olhando, que muda com o pan.
  - **[P]** O terminal sobe e desce numa animação curta, com som de subir e de descer, também quando sobe ou desce sozinho na troca de fase; no fim do turno, a subida vem depois do escurecimento (dono, 14/11). A duração se escolhe testando com `?terminal=<s>`. Enquanto anima, nos dois sentidos, a sala não recebe clique.
  - **[P]** Aberto, o terminal trava o pan, e a sala que estava na tela aparece pelas frestas da moldura (as bordas, os vãos entre as teclas e a faixa de baixo), sem clique. A tela do terminal não encolhe (dono, 14/11).
  - **[P]** O alerta da radiação não some com o terminal aberto (dono, 14/11): quando o medidor passa do limiar de abrigo, toca um alarme, o alerta fica visível por cima do terminal, e tocar a linha do abrigo na aba tarefas fecha o terminal e vira a sala para o botão do abrigo. Abrigar continua sendo o toque no botão. O porquê: as tarefas ficam no terminal, o P0 escondia o alerta com ele aberto, e cada segundo de atraso custa de 0,24 a 0,67 de margem.
  - **[P]** Os botões fazem um clique com som, um por peso da ação: navegar (abas, voltar, fechar o card, O2 − e +, marcar tarefa), confirmar (confirmar, enviar, iniciar, consertar, reiniciar, seguir, jogar de novo, estufa, glovebox e a porta do dormitório) e abrigo. O botão do terminal e as setas não fazem clique (dono, 14/11).
- **[P]** Abas:
  - **câmeras**, escolhidas num mapa de Gale, com sobreposição de alvo e telemetria, como as vistas da estação robótica da ISS;
  - **tarefas**, a lista do turno;
  - **diário**, o registro do que passou: os diários dos sóis anteriores e as mensagens da Terra que já venceram;
  - **fontes**, com o número, a fonte e a data do DONKI, mais o detalhe que sai do plano: a conta da energia e o tanque de O2. Atende à regra de que a fonte de cada número aparece no jogo.
- **[R]** No máximo 4 abas e nenhuma sub-aba, porque a tela leva só o necessário e a navegação é rasa (NASA-STD-3001 [V2 10040] e [V2 10043]).
- **[P]** As abas são teclas grandes na moldura, como as bezel keys das telas da Orion.
- **[P]** O terminal tem a aparência de prancha (blueprint) da versão do primo: fundo azul-marinho `#122a4a`, grade, borda dupla e o selo "PRANCHA 01 · GALE · SOL N" (dono, 15/11). A estrutura continua a das 4 abas; a tela inicial com blocos e "Voltar" da versão dele não entra, porque cada troca custaria dois toques. O azul é o escuro, não o `#1f4f8f` dele: neste, o vermelho de alerta fica a 2,2:1, a energia a 2,96:1 e o texto suave a 4,0:1. Só o terminal muda; as telas da sala ficam como estão. O trilho da rolagem da aba fontes passa à borda da prancha (`#6f8fb8`, 3,6:1 sobre a caixa), porque a borda neutra dá 1,4:1 ali. Entra antes das 16:00 (dono, 15/11, 13:05: as peças do primo passaram à frente da 3ª rodada).
- **[P]** A tela inicial do painel do primo: quando o terminal sobe no começo do plano e do fim do sol, mostra primeiro blocos grandes, cada um com o nome, uma linha que explica e uma linha de estado ao vivo (dono, 15/11). O maior bloco é a ação da fase; os outros quatro são as abas. No turno ela nunca aparece, e as teclas da moldura continuam indo direto a cada aba, então ela é a porta de entrada da fase, e não uma sub-aba. O porquê: o primo acha o painel dele "muito mais fácil de entender" (15/11, 11:37), e o dono concordou em aproximar o terminal dele. A ordem no começo do plano (dono, 15/11): a página do diário, a tela inicial e, depois do toque no bloco do plano, a fila de cards. O porquê: os cards do sol 1 apontam controles que só existem na tela do plano. Entra antes das 16:00 se o gancho estiver pronto às 14:30; se não, depois da entrega.
- **[R]** Cores: verde só no que se clica, como na Orion, fora do Painel; dentro dele, o que se clica é um contorno claro sobre a prancha, que se preenche no toque, como no painel do primo, e a ação principal de cada tela tem o contorno mais grosso (dono, 15/11); vermelho e amarelo só em alerta (NASA-STD-3001 [V2 10118] e [V2 10119]); azul-claro sólido, com a antena, só no que vem da Terra (a prancha azul-marinho do terminal não conta, dono, 15/11).
- **[R]** O terminal não guarda as ordens da Terra que ainda valem: elas ficam na tela de comunicação. Quando vencem, vão para o diário.

## Tarefas (minigames)

- **[R]** Toda tarefa mexe numa barra: ou protege um recurso (manutenção), ou gasta energia para render ciência.

| Tarefa | Tipo | Barra | Interação | Base real |
|---|---|---|---|---|
| Limpar o painel | manutenção | Energia | Arrastar a escova do braço sobre a poeira | Poeira derrubou o InSight; em 2021 a pá soltou areia ao vento, que tirou parte da poeira de um painel (+30 Wh por sol) |
| Consertar o gerador | manutenção | Oxigênio | Achar a peça certa e encaixar | Filtro entupido e sensor de hidrogênio trocado nos geradores da ISS |
| Laser do ChemCam | ciência | Energia → ciência | Mirar pontos numa rocha e disparar | 30 pulsos por ponto |
| Selar a amostra | ciência | Energia → ciência | Perfurar, encher o tubo e selar | 43 tubos no Perseverance; a primeira coleta saiu vazia |
| Cultivar planta | ciência | Energia → ciência | Regular luz e água | Veggie e APH na ISS; material da CSA citado no desafio |

- **[P]** As interações e a dificuldade de cada tarefa.
- **[P]** Onde cada tarefa se faz: painel, gerador (MOXIE) e ChemCam pelas câmeras do terminal; amostra e planta abrem numa vista de perto, na frente da glovebox e da estufa, com o turno correndo; não passam pelo terminal (dono, 15/11).
- **[R]** A tarefa que tem minigame termina quando a criança termina a peça, e não pelo relógio (dono, 15/11). O porquê: com o relógio, a tarefa ficava feita aos 10 s mesmo sem nenhum toque, e a peça virava enfeite. O tempo da tarefa passa a ser o da criança. O teto da calibração só vale com a peça de até 10 s (medido em 15/11): com 15 s por peça mais 3 s de navegação, só uma tarefa fica pronta antes do pico do sol 2, a equilibrada cai de 5 para 4 de ciência, e 3 de ciência mais o conserto no sol 5 somam 67 s. As 3 estrelas seguem alcançáveis até cerca de 20 s por peça.
- **[P]** O turno fica em 60 s, com o relógio correndo durante a peça (dono, 15/11). O dono cronometra uma missão no build integrado; se 3 de ciência mais o conserto não couberem em 60 s para um adulto, o relógio passa a parar com a peça aberta e a andar 10 s quando ela fecha, o que deixa a calibração idêntica. O turno de 90 s ficou de fora: com Planta e Amostra ainda em 10 s, a receita de 7 de ciência passa a dar 2 modos de segurança.
- **[R]** Abrigar é um toque no botão do abrigo, ao lado da porta, não minigame (dono, 14/11; o lugar passou da porta ao botão quando a porta virou o dormitório). O porquê: arrastar a carga punia a habilidade motora e fazia a dose depender do reflexo. A base real é o procedimento da Artemis II, com a carga nas paredes.
- **[R]** O abrigo custa tempo: a ciência feita antes de abrigar conta, e depois a tripulação não faz mais tarefas no turno (dono, 14/11). Abrigar cedo demais perde ciência à toa, e tarde demais recebe dose.
- **[R]** Tarefa de ciência não feita até o fim do turno: o plano só reserva a energia, e a tarefa a gasta quando roda, como o instrumento real só gasta quando liga. A reserva da tarefa não feita volta à bateria, respeitando o teto (o excedente se perde).
  - O porquê: perder a energia puniria a habilidade motora em vez da escolha, e faria o abrigo custar energia, não só tempo.
  - Consequência para a calibração: ela supõe toda tarefa escolhida feita, então vale como teto.
- **[R]** Tarefa de manutenção não feita: a consequência vem pela própria barra, e a tarefa continua na lista no sol seguinte. O diário registra a consequência antes de ela pesar.
  - painel sujo rende menos no sol seguinte;
  - gerador quebrado produz zero O2. O plano mostra "gerador quebrado: 0 O2, conserte no turno".
- **[R]** Sem abrigo, a tripulação recebe a dose da tempestade no próprio turno.
- **[P]** O conserto do gerador no turno libera a produção de O2 do mesmo sol.
- **[R]** O gerador quebra uma vez na missão, num sol marcado da agenda (ver "Missão e sol"), e no freeplay num sol sorteado. A reserva de O2 é o seguro contra a quebra (dono, 14/11). O porquê: sem quebra, o tanque de O2 nunca compensava, e a pergunta-guia "reserva de oxigênio por pesquisa" ficava sem escolha. **[P]** Quantas quebras e em que sóis. No P0 o tanque ainda não muda o resultado em nenhum caso medido (14/11), porque o conserto é um clique sem custo que libera o O2 do mesmo sol; está em "Em aberto".
- **[R]** Pedido de ciência da Terra não feito vence no fim do sol e vai para o diário.

## Eventos

- **[R]** Uma tempestade solar e uma tempestade de poeira por missão, mais a poeira que acumula o tempo todo.
- **Tempestade solar** **[R]**:
  - o aviso aparece na fase de plano antes do pico, numa janela incerta: o DONKI mostra uma semana de Sol agitado, com CMEs previstas a caminho de Marte. Na missão, o aviso é do sol 1 e a janela são os sóis 1 a 3, como as cinco chegadas que o DONKI previa para 19 a 21/05/2024;
  - o que sobe a dose não é a chegada da nuvem prevista, e sim as partículas rápidas de uma explosão nova, que chegam em dezenas de minutos (dono, 14/11). O porquê: em 2017 a chegada da nuvem fez a leitura do RAD cair, e ligar o pico à chegada prevista ensinava o contrário (dados-nasa-do-junior-astronaut (pesquisa no vault do dono));
  - no turno, o pico de partículas vem de repente, e quem olha o medidor e abriga na hora leva menos dose;
  - base: em maio de 2024 o DONKI previu cerca de 10 chegadas de CME a Marte, mas o maior pico desde o pouso veio de um flare e de uma CME do próprio dia 20/05, para a qual o DONKI não previu impacto em Marte. As partículas chegaram em dezenas de minutos. O escritório de clima espacial do Goddard sinalizou a possibilidade das partículas depois da explosão (JPL, 10/06/2024), então "ninguém avisou" e "só o medidor da base viu" não valem como fato;
  - na tela, no aviso (dono, 15/11): "O Sol está muito agitado nesta semana. Uma explosão nova pode mandar partículas rápidas. Elas podem chegar em dezenas de minutos. Se o alarme tocar, vá para o abrigo. O botão do abrigo fica à esquerda." O porquê: o release do JPL diz "tens of minutes", e não minutos; e o medidor fica fora da vista de repouso e some com o terminal aberto, então a criança reage ao alarme. No "o que aconteceu de verdade": "Em maio de 2024, a previsão da NASA (DONKI) mostrou uma semana de tempestades solares a caminho de Marte. Em 20 de maio, uma explosão enorme no Sol lançou partículas rápidas, que chegaram a Marte em dezenas de minutos. O Curiosity mediu o maior salto de radiação desde o pouso." (dono, 14/11)
- **Tempestade de poeira** **[R]**:
  - não tem aviso do início, porque não há previsão real;
  - o painel quase para por alguns sóis, e só salva quem guardou energia antes;
  - limpar o painel não resolve, porque a poeira está no céu;
  - base: em 2018 o Opportunity caiu de 645 para 22 Wh e não acordou mais. A tempestade real começou em 30/05/2018 e só acabou entre agosto e setembro; a de 2 sóis é encurtada, e a tela diz isso;
  - na missão, a poeira cobre os sóis 3 e 4, pela agenda; no freeplay, o sol de início é sorteado em cada bloco, e o sorteio se mantém quando o sol recomeça (dono, 14/11);
  - comportamento-alvo (14/11): numa tempestade de 2 sóis, quem aposta tudo em ciência entra em modo de segurança, e quem divide passa. Medido na agenda da missão com os números do P0: "tudo em ciência" faz 9 de ciência com 1 modo, no sol 4; a equilibrada faz de 4 a 5 sem nenhum; a que enche o tanque de O2 faz 0 com 2 modos, porque a poeira a pega sem bateria; o melhor plano sem modo faz 7;
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
  - o card entra com o movimento dos avisos da versão do primo: vem da esquerda com um pequeno quique e cresce até o tamanho final em cerca de 0,35 s (dono, 15/11). Do aviso dele, o resto não entra: o fundo piscava 3,3 vezes por segundo, o aviso sumia sozinho em 3,5 a 6 s e cobria o HUD.
- **[P]** Os cards do plano do sol 1 apontam o controle que nomeiam com o ponteiro do tutorial do primo: uma seta do card até o controle e uma moldura pulsante em volta dele, a cerca de 1 Hz, em azul da Terra e sem rótulo (dono, 15/11).
- **[P]** O alerta da radiação, ao aparecer, treme como o aviso do primo e dá um único flash vermelho na tela, junto do alarme (dono, 15/11).
- **[P]** Quando uma tarefa de ciência termina, sobe um selo com o ícone da ciência e "+N", sem palavras, que some em cerca de 1,5 s, perto das notificações e sem cobrir o medidor nem as barras (dono, 15/11). Pode sumir sozinho porque não tem texto para ler.
- **[P]** Rótulo no card: "enviado da Terra há 16 min" na missão (dono, 15/11): em 19/05/2024 a luz levava 15,9 min de Marte à Terra (JPL Horizons). No freeplay, o atraso é sorteado entre 3 e 22 min.
- **[P]** O medidor da base acusa o pico antes do aviso da Terra. Com 1 s = 1 min, o card do pico chega de 3 a 22 s depois do medidor, e quem espera a Terra leva mais dose.

## Falha e relatório

- **[R]** Não há game over. Quando falta energia para o aquecimento, o oxigênio acaba ou a margem de radiação zera, entra o **modo de segurança**, como o safe mode real: a base corta o não essencial, a tripulação se protege e a ciência para.
- **[P]** A entrada no modo de segurança toca o som de desligar, uma vez; quando o relógio acaba, no começo do escurecimento (dono, 14/11).
- **[R]** Uma tela explica a causa em 1 a 2 frases, com número ou caso real:
  - energia: o Opportunity em 2018;
  - radiação: a tempestade solar de referência de outubro de 1989, que a NASA usa para projetar a proteção da tripulação (dono, 15/11: a norma fala em proteção, não em abrigo). Maio de 2024, o maior pico medido em Marte, ficou abaixo do limite, então não serve de caso de falha: a tela diz que no jogo a dose foi ampliada;
  - oxigênio: cerca de 0,9 kg por pessoa por dia, até um caso confirmado.
- **[R]** A tela diz a causa pelo contexto, e não só a barra que zerou (dono, 14/11): a poeira que parou o painel e o gerador, o gerador quebrado que ninguém consertou, ou o abrigo que veio tarde. O porquê: em "tudo em ciência", toda falha é por oxigênio num sol de poeira, um ou dois sóis depois da última escolha que salvava, e "o oxigênio acabou" não ensina a guardar bateria. Quando há contexto, a tela mostra só a frase do contexto, sem a frase da barra na frente (dono, 15/11): somadas, as duas chegavam a 91 palavras, contra a regra de 1 a 2 frases.
- **[R]** O abrigo tardio falha no próprio sol da tempestade solar (dono, 15/11): se a margem que sobra desse sol não cobre a radiação de fundo dos sóis que faltam, o sol entra em modo de segurança ali, com a causa do abrigo tardio e "o simulador reinicia o sol". O porquê: quem demorava de 14 a 21 s para abrigar passava o sol 2 e perdia de um a três sóis adiante, cada um aberto direto na tela "a margem acabou, isso veio dos sóis anteriores", sem citar o abrigo; quem demorava 22 s ou mais reiniciava o sol 2 e saía melhor. Passa a contar 1 modo de segurança em vez de até 3, e faz as vezes do treino de emergência, que ficou para depois da entrega. Não muda a calibração: a menor margem depois do sol 2 entre os planos medidos é 6. Fica para depois da entrega (dono, 15/11, 13:05), porque as peças do primo passaram à frente da 3ª rodada. Até lá, a causa do abrigo tardio só aparece para quem demora 22 s ou mais e entra em modo de segurança no próprio sol 2 (`causa_sem_abrigo` exige `eh_sol_solar()`).
- **[R]** Quando nenhum plano salva o sol, a tela do modo de segurança vem antes do plano, e a criança não joga um sol perdido (dono, 14/11). O P0 só antecipava a falta de energia.
- **[R]** Depois do modo de segurança, a saída depende de o sol ter conserto (14/11):
  - se algum plano salva o sol, o botão "o simulador reinicia o sol" volta ao começo da fase de plano do mesmo sol;
  - se nenhum plano salva, porque a causa veio de sóis anteriores (por exemplo, a bateria vazia quando a poeira chegou), o botão vira "seguir em modo de segurança": a base sobrevive com o mínimo, o sol passa sem ciência, conta 1 modo de segurança, e a tela diz que a causa veio antes;
  - o teste de "algum plano salva" é rodar o plano de emergência: tudo ao gerador, consertar o que estiver quebrado e abrigo no sol da tempestade solar. Sem o conserto no teste, o gerador quebrado daria zero e mandaria para "seguir em modo de segurança" um sol que tinha salvação;
  - o porquê: sem a segunda saída, a criança recomeça um sol impossível sem fim, e o desafio pede aprender com a falha sem punição.
- **[R]** Nada de tela piscando: no máximo 3 flashes por segundo, transição suave e som sempre com equivalente visual.
- **[P]** Todo som passa por um barramento só, com um volume geral, e um botão de mudo fica no canto direito da faixa de baixo, ao lado do botão do terminal, fixo em todas as fases e guardado no navegador para a próxima vez (dono, 14/11). O canto superior direito foi descartado porque o terminal aberto o ocupa.
- **[R]** No fim da missão vem o relatório, o debriefing, que é a carga da nave (dono, 14/11):
  - a ciência enviada, a margem final e quantos modos de segurança. O relatório diz "Ciência enviada: N", sem "de M" (dono, 15/11); na missão fixa, uma linha diz "o melhor sem modo de segurança: 7", e no Modo livre essa linha não aparece. O porquê: com M = 7, quem arrisca faz 9 e lia "9 de 7", e o Modo livre chega a 10 a 12;
  - uma nota em estrelas, em que cada modo de segurança conta contra. As estrelas se medem pelo ótimo da missão fixa: 3 pedem nenhum modo de segurança e ciência perto do máximo sem modo, que com os números do P0 é 7 (dono, 14/11). **[P]** A regra de partida (dono, 14/11; os limiares são do primo): 3 estrelas com nenhum modo e ciência a partir de 5; 2 com nenhum modo; 1 quando houve modo. O relatório diz o que faltou para a estrela seguinte. Com o pico aos 25 s e a peça de até 10 s, a equilibrada leva 3, e "tudo em ciência" e a que enche o tanque levam 1. No P0, até 2 modos ainda davam 2 estrelas;
  - "o que aconteceu de verdade", com a data do caso real, e a linha que assume a compressão do tempo: no simulador a nave chega em 5 sóis; de verdade, o caminho para Marte abre a cada 26 meses (postos-avancados-lua-e-marte (pesquisa no vault do dono));
  - a frase da escala da radiação (cada sol vale muitos dias de radiação de verdade), que no P0 só aparece na aba fontes.
- **[P]** Sucesso é chegar ao relatório; as estrelas medem o resto (dono, 14/11).

## Freeplay

O modo que vem depois da missão. Fechado pelo dono em 14/11 e fora da ordem de construção da entrega: a missão vem primeiro.

- **[R]** O freeplay só destrava depois do relatório dos 5 sóis, sem atalho, e o destrave fica guardado no navegador. O vídeo de 30 s o mostra, porque o jurado só chega a ele se terminar a missão.
- **[R]** No freeplay os eventos são sorteados, um por vez.
- **[P]** Ele anda em blocos de 5 sóis. A cada bloco chega uma nave com carga (de partida: mais 6 de bateria, mais 4 de oxigênio e painel limpo, até os tetos) e uma tripulação nova, com a margem de radiação cheia. "Nunca enche" continua valendo, porque a margem é de cada tripulação. O porquê: sem tripulação nova, a margem zera no sol 6 para qualquer estratégia.
- **[P]** Cada bloco sorteia uma tempestade solar e uma de poeira. A tempestade solar reencena uma CME real da janela de 60 dias do build (ver "Dados").
- **[P]** O freeplay acaba na primeira falha: um foguete leva a tripulação de volta à Terra, e o relatório mostra o recorde. A poeira dura mais a cada bloco (de partida: 2, 2, 3, 3, 4 e 4 sóis). O "não há game over" segue valendo na missão.
- **[P]** Para a entrega, a versão zero do freeplay (dono, 14/11): depois do relatório da missão fixa, o "Jogar de novo" abre uma missão de 5 sóis com os eventos sorteados, um por sol. O P0 já sorteia; falta guardar no navegador que a missão fixa foi concluída. O porquê: mantém a rejogabilidade com eventos variáveis, que o desafio lista em "para se destacar", sem esperar a nave e os blocos.
- **[P]** A ideia do drone: freeplay-drone.

## Dados

- **[R]** O DONKI vai **embutido e atualizado no build**: um script baixa os últimos 60 dias do CCMC na hora do export, e o jogo mostra a data ("dados do DONKI de 15/11/2026").
- **[R]** A missão principal usa sempre o recorte histórico de maio de 2024, com o RadLab: o sol 1 é 19/05/2024, e a tempestade solar do sol 2 é a de 20/05. O dado do build não muda a missão (dono, 14/11). O porquê: é o único recorte com dose medida, e a missão não pode mudar a cada build.
- **[R]** Dado estático nunca aparece como ao vivo (desafio).
- **[P]** As chegadas a Marte que o DONKI prevê na janela de 60 dias costumam já ter passado na hora do build. No freeplay, cada tempestade solar reencena uma CME real dessa janela, e o jogo nunca apresenta a chegada como algo que ainda vai acontecer; a força da tempestade é a do simulador (dono, 14/11).
- **[P]** Enquanto o freeplay não existe, o dado do build aparece na missão como dado de hoje, com a data: no card do aviso e na aba fontes, quantas chegadas a Marte o DONKI lista na janela, a data da última e se é de raspão (dono, 14/11). A velocidade saiu (dono, 15/11): a documentação do DONKI não diz se ela é a da saída do Sol ou a da chegada, e "a N km/s" ao lado da data se lê como velocidade de chegada. O P0 reencenava na missão a chegada mais recente do build.
- **[R]** O dado vem de `scripts/baixar_donki.py`, que o `scripts/publicar.sh` roda antes do export; o formato está no docstring do script.
- **[R]** Se o filtro de impacto em Marte vier vazio na janela, vale o recorte histórico.
- **[R]** Nenhuma dose medida fica ligada à CME recente reencenada: o RadLab só tem o Curiosity até maio de 2024.
- **[R]** Coleta zero:
  - sem analytics, cookies, login ou chamada a terceiros no código;
  - as fontes vão empacotadas no build;
  - progresso só em localStorage;
  - nenhum IP de criança sai do navegador para a NASA (jogos-educativos-7-a-12-anos (pesquisa no vault do dono)).
- **[R]** A fonte de cada número aparece dentro do jogo (desafio).

## Arte

- **[R]** Render prévio no Blender, um PNG por estado com a mesma câmera, e o jogo em 2D com panorama: [0002](decisoes/0002-a-arte-e-renderizada-antes-no-blender-e-entra-como-panorama-2d.md).
- **[R]** Pixel art em 640×360 e filtro Nearest nas texturas. A resolução interna é fixa; a escala na tela é fracionária (dono, 14/11). Com a escala inteira, o jogo ocupava de 10% a 42% da tela no celular e 26% num notebook de 1366×768 em janela; o custo da fracionária é a borda do pixel levemente suavizada.
- **[R]** Fonte com acentos e licença aberta. O jogo usa a fonte padrão do Godot, a Open Sans SemiBold, sob OFL-1.1 (conferido em 14/11 no `COPYRIGHT.txt` do Godot 4.7.2). A Pixeloid ficou de fora porque toda caixa de texto do P0 foi medida para a fonte padrão (dono, 14/11).
- **[R]** Nenhum asset do FNAF nem de fangame.
- **[R]** IA de imagem só para retoque por inpainting, com cada uso no registro-uso-de-si.
- **[R]** Os créditos trazem as licenças: Godot (MIT), shader (CC0), fonte (Open Sans, OFL-1.1), sons (CC0, com autor e origem) e o Cupcakes Framework (MIT), se for usado. São um bloco no fim da aba fontes, e não uma tela própria, porque o terminal já está no limite de 4 abas (dono, 14/11). O README repete a lista e acrescenta as fontes de dado: DONKI/CCMC, RadLab/OSDR, a paleta e as fontes citadas no jogo.
- **[P]** Câmera do render: a cilíndrica central do Cycles (`CENTRAL_CYLINDRICAL`), com 180° em 1280×360, e o shader de panorama com `zoom` = (1 − cos(metade do ângulo da janela)) / 0,0015, que dá 195 para a janela de 640 px. A perspectiva não serve: o shader curva o que ela já deixa reto, e em 1280 px ela não alcança a porta do abrigo na parede lateral. Medido no protótipo de 14/11 (`arte/blender/comparar_camera.py` no repo).

## Ordem de construção e de corte

- **P0, o jogo inteiro e mínimo (sábado):**
  - export Web vazio no ar na primeira hora, testado na máquina do playtest (risco do WASM SIMD em máquina velha);
  - um cômodo com arte provisória;
  - o terminal com o botão único e a fase de plano dentro dele, com as três barras;
  - o fim do turno pelo relógio, um diário mínimo com "Enviar à Terra", modo de segurança e relatório;
  - a tempestade solar com o dado embutido, com o aviso da Terra num card azul simples;
  - o abrigo, com um toque no botão;
  - uma tarefa de ciência mínima: o ChemCam com um clique;
  - a tempestade de poeira só como efeito na barra de energia;
  - consertar o gerador, com a quebra sorteada;
  - o botão "Encerrar o sol".
  - O porquê (dono, 14/11): sem ciência e sem poeira, "tudo em ciência" ganhava das outras estratégias em tudo, o que fere "nenhuma escolha segura sem custo".
- **P1, o que dá o desenho (sábado à noite e domingo de manhã):**
  - primeiro, o plano enxuto, o card por cima do plano e as 4 abas do terminal, com a de fontes já preenchida (o plano enxuto depende dela);
  - o terminal animado com som, os cliques, o desligar, o mudo e a porta do dormitório (dono, 14/11);
  - o conteúdo das abas de câmeras e de tarefas;
  - a poeira escurecendo a janela. Limpar o painel fica para depois da entrega (dono, 15/11): a peça existe, mas o painel nunca suja enquanto o acúmulo de poeira não tiver regra, e uma tarefa sem efeito numa barra fere "toda tarefa mexe numa barra";
  - o ChemCam completo, com mira;
  - os cards azuis com destaque e a tela de comunicação;
  - sol 1 guiado, na versão mínima com cards azuis;
  - o diário completo;
  - a sala acompanhando o pôr do Sol;
  - menu inicial com o botão Jogar;
  - português e inglês, com o seletor na tela;
  - arte final.
- **P2, se sobrar:** amostra na glovebox, planta na estufa, câmera do céu e estática nas câmeras.
- **Depois da entrega:** o freeplay completo (nave, tripulação nova, blocos e foguete), o roteiro por sol com o treino de emergência, o plano do sol 1 em passos, o medidor movido pela curva do RadLab, limpar o painel com a regra do acúmulo de poeira, e o tanque de O2 como escolha (dono, 14/11: mexer no balanço no último dia refaria o ótimo, os testes e os números da submissão). Também depois da entrega, da versão do primo: as pesquisas do dia como pedidos da Terra com valor, a pista falsa e o que já estava adiado (dono, 15/11). As pistas verdadeiras da página do diário entram na entrega.

Se atrasar, corta-se nesta ordem: planta → amostra → câmera do céu → estática. O P0 nunca se corta.

Ordem das últimas horas (dono, 14/11, à noite):
1. fechar a fatia do terminal sem ampliá-la, só com o alarme e o caminho até o abrigo;
2. a agenda fixa da missão, com o máximo teórico e os testes refeitos, e o "Jogar de novo" sorteando os eventos;
3. os textos de tela com erro de fato;
4. a tela do modo de segurança com a causa pelo contexto;
5. a abertura e o sol 1 guiado mínimo, com a frase do objetivo (dono, 15/11: a abertura entra aqui, antes dos minigames);
6. o seletor de idioma;
7. os créditos no fim da aba fontes e o README;
8. a missão datada em maio de 2024, só em texto, mais DONKI no card do aviso e o relatório como carga da nave;
9. as estrelas, pela regra de partida.

Entre 12:00 e 16:00, junto dos itens 5, 8 e 9 (dono, 15/11): a aba de câmeras, com o ChemCam com mira e o conserto do gerador como minigames. As peças foram feitas na noite de 14 para 15/11 (chats-da-noite-15-11) e estão juntas na branch `teste-minigames`; limpar o painel fica de fora. Os itens 1 a 4 vêm antes, porque mudam o que o jurado vê.

Ordem até as 16:00 (dono, 15/11, às 13:05), cortando de baixo para cima. Substitui a das 11:20: as peças da versão do primo passam à frente do que sobrou da 3ª rodada. Já estão no `main` (`fe66a9b`): as estrelas, a integração dos minigames, os créditos no fim da aba fontes e a história do sol no diário.
1. a página do diário (branch `pagina-diario`);
2. a viagem Terra → Marte (branch `viagem`);
3. os avisos e o ponteiro do tutorial (branch `prancha-e-avisos`, os dois primeiros ganchos);
4. a prancha (terceiro gancho), com o trilho da rolagem na borda da prancha;
5. a tela inicial do terminal (quarto gancho), se o gancho estiver pronto às 14:30;
6. o som da viagem, sintetizado;
7. o relatório sem "de M", com a linha do melhor sem modo de segurança. Se não entrar, o plano 6 do vídeo não mostra a linha da ciência;
8. a tela do modo de segurança só com a frase do contexto;
9. os textos de tela da 3ª rodada e o atraso de 16 min no card;
10. o abrigo (4 vezes na fonte, 5 no jogo) na lista da aba fontes. Se não entrar, a marca `{{3}}` da submissão corta a frase e a referência de agência parceira;
11. a velocidade fora do card do DONKI.

O abrigo tardio sai da ordem e fica para depois da entrega (dono, 15/11, 13:05). A marca `{{4}}` da submissão continua valendo, pelo caso de quem entra em modo de segurança no próprio sol 2.

Um chat por vez integra no `main`; a preparação corre em paralelo, cada uma em worktree própria (dono, 15/11). Os horários e os prompts de cada fatia estão no briefing das peças do primo, no vault. Os commits das peças levam o primo como coautor pelo trailer do GitHub dele. A amostra e a planta do primo seguem com ele, cortadas às 14:30 sem PR revisado.

O nome do primo, menor de idade, não entra em nada público (dono, 15/11): nem no repo (código, comentários, `docs/`, mensagens de commit novas e nomes de branch), nem no README, nem na submissão. Ele aparece como "o primo" ou "our teen teammate", e o trailer `Co-Authored-By` com o usuário do GitHub dele fica. O porquê: o regulamento proíbe nome, voz e imagem de menor de 18 na submissão e no projeto. O crédito das ideias dele (o painel em prancha, o diário com pistas e a viagem) vai no README e na descrição detalhada, sem nome, como "our teammate under 16", pelo Young Innovators Award; ele tem menos de 16 anos (dono, 15/11).

Fora do código, depois do congelamento e antes da tag (dono, 15/11): a trava no `publicar.sh`, que publica a pasta de onde é chamado, com force-push e sem conferir a branch; a fonte certa em `docs/briefing.md`; o crédito das ideias do primo no README; e uma cópia só do registro de uso de IA, no repo, com as linhas que vêm no corpo dos commits de gancho.

Em paralelo, ainda no sábado: o roteiro do vídeo de 29 s e o rascunho dos campos do formulário, em inglês. Estão em submissao.

O código congela no domingo às 16:00, com um envio de segurança às 12:00. Depois do congelamento vêm a publicação, a tag no commit publicado, o vídeo de 30 s e o formulário (dono, 14/11). A publicação sai do `main` limpo, o `dados/donki.json` do build final é commitado, a tag vai no `main` e no commit do `gh-pages`, e depois disso o `publicar.sh` não roda mais até o fim do julgamento (dono, 15/11). O porquê: o script baixa o DONKI de novo a cada publicação, então a tag sozinha não reproduz o build.

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
- O que a 3ª rodada da revisão, de 15/11 de manhã, deixou sem decisão: https://claude.ai/artifact/91EzuWstkjndBF9n17XGh2. São: a receita "O2 +2 e todas as tarefas", que faz 7 de ciência sem olhar evento; os segundos vazios do turno; o Modo livre fácil em 4 das 6 agendas e sem recorde; um abrigo tardio que vale 1 estrela na missão inteira; a duração para uma criança de 7 anos; "modo de segurança" sem definição na tela; o contraste do vermelho do aviso de falha do plano; tela cheia e trava de orientação; a leitura do RadLab no diário do sol 2; o toque que avança a abertura; o porte antigo da calibração da agenda fixa; a média do RAD sem peso pelo tempo; o logo do Godot na tela de carregamento; e o card do aviso no Modo livre.
- O que a revisão da noite de 14/11 deixou sem decisão: https://claude.ai/artifact/A3Kn5XBZtPkJ5Dg4iv1ZGV. São: o tanque de O2, que não muda o resultado em nenhum caso medido e fica para depois da entrega (dono, 14/11); o fator do abrigo (5 no jogo, cerca de 4 na fonte); o acúmulo de poeira do P1, 25 vezes o do InSight; os turnos vazios e a duração do turno contra o playtest; e as duas cópias do registro de uso de IA.
- A 1ª rodada da revisão, de 14/11 à tarde: https://claude.ai/artifact/KYBpTRojemg14ztGLzBLu1.

## O que não faz (propostas recusadas)

- Plano dividido em abas: o terminal já tem as 4 abas do limite, e o efeito previsto sairia de perto do controle.
- Plano em passos nos sóis 2 a 5: separar oxigênio e ciência esconderia a troca entre eles, que é a lição do jogo. Fica só no sol 1.
- Barra de comida ou de fome: a tripulação tem comida suficiente, e o jogo não toca no assunto (dono, 14/11). A planta e a amostra são tarefas de ciência.
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
- Abrir no idioma do navegador: fica o inglês por padrão, com o seletor na tela (dono, 14/11).
- A linha do abrigo na aba tarefas abrigar direto: abrigar continua sendo o toque no botão da sala, e a linha só leva até ele (dono, 14/11).
- Tela de créditos própria e troca para a Pixeloid: o terminal está no limite de 4 abas, e toda caixa de texto foi medida para a fonte padrão (dono, 14/11).
- Missão principal com eventos sorteados: o sorteio é do freeplay (dono, 14/11).
