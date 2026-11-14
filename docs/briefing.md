# Briefing do time: estado em 14/11/2026, 09:30

Para quem chega agora no Five Sols on Mars. Este texto conta o que já foi decidido, o que já está feito e o que está em aberto. O desenho completo está em [spec/five-sols-on-mars.md](spec/five-sols-on-mars.md), e os termos em [spec/glossario.md](spec/glossario.md). Se este briefing e a spec divergirem, vale a spec.

## Em um minuto

- **Evento:** NASA Space Apps Challenge 2026, de 14/11 às 09:00 até **15/11 às 23:59**, no fuso do evento local (Campinas).
- **Desafio:** [Build a Junior Astronaut Mission Trainer](https://www.spaceappschallenge.org/2026/challenges/junior-astronaut-mission-trainer/). É um jogo em que crianças de 7 a 12 anos gerenciam um posto avançado e sentem que toda escolha tem custo.
- **O nosso jogo:** a criança comanda por 5 sóis (dias marcianos) um posto na cratera Gale, em Marte, de dentro do módulo de comando. Ela divide a energia, faz tarefas de uma tela e se protege das tempestades do Sol e da poeira. A falha não é game over: entra o modo de segurança e o simulador reinicia o sol. No fim, um relatório.
- **Já está no ar:** https://freitasvarejo.github.io/five-sols-on-mars/, por enquanto só a tela com o nome.
- **Divisão:** você fica com o game design e a programação do jogo. O dono fica com a arte, os dados da NASA, os textos com fonte, o deploy e a submissão. A divisão fina ainda está aberta (fim deste texto).
- **Marcas da spec:** **[R]** é restrição (vem do desafio, do dado, da pesquisa ou do regulamento) e não muda sem reabrir a fonte. **[P]** é proposta, e você pode trocar.

## Antes de programar

1. Passe ao dono o seu usuário do GitHub, para ele te adicionar como colaborador do repo.
2. Inscreva-se no Space Apps, no **mesmo evento local** (Campinas), e entre no time. Quem não está no mesmo evento, ou está na lista de espera, tira o time do julgamento global.
3. Instale o **Godot 4.7.2**, exatamente esta versão, e os **export templates** da mesma release: https://github.com/godotengine/godot/releases/tag/4.7.2-stable (`Godot_v4.7.2-stable_<seu-sistema>` e `Godot_v4.7.2-stable_export_templates.tpz`). Os templates entram pelo editor, em Editor → Manage Export Templates → Install from File.
4. Clone: `git clone git@github.com:FreitasVarejo/five-sols-on-mars.git`. O Claude Code lê o [CLAUDE.md](../CLAUDE.md) do repo sozinho.

## O que já está decidido

### Plataforma

- Navegador, sem download e sem conta, exigência do desafio. **Godot 4.7.2**, renderer **Compatibility** (o único que roda na Web), export Web **single-threaded**, publicado no **GitHub Pages**.
- Tela de **640×360** com escala inteira e filtro Nearest, em pixel art. A fonte é a Pixeloid (OFL), que tem acentos.
- **Coleta zero:** sem analytics, cookies, login ou chamada a terceiros no código. Progresso só em `localStorage`. Os dados da NASA vão **embutidos no build**, nunca buscados ao vivo do navegador, porque isso mandaria o IP da criança para fora.
- Inglês por padrão e português num seletor, com as strings numa tabela CSV desde a primeira hora.

### Arte e câmera ([ADR 0002](spec/decisoes/0002-a-arte-e-renderizada-antes-no-blender-e-entra-como-panorama-2d.md))

- O cômodo é 3D gerado por script no Blender e renderizado como PNG em pixel art, um por estado (normal, tempestade, abrigo, modo de segurança), sempre com a mesma câmera.
- No Godot, o jogo é **2D**: o PNG é um panorama largo com pan pelo mouse e por setas grandes (toque não tem mouse), e o shader CC0 "Accurate FNAF Clickteam Panorama" faz o falso 3D.
- O shader distorce a imagem, mas não os cliques. Por isso os botões são `TextureButton`, grandes, na faixa vertical central.
- Nenhum asset de FNAF ou de fangame. IA de imagem só para retoque.

### Cenário ([ADR 0001](spec/decisoes/0001-o-posto-do-jogo-fica-em-marte-nao-na-lua.md))

Marte, e não a Lua, porque só lá o dado do jogo é o próprio dado da NASA. O DONKI prevê tempestades solares chegando a Marte, e o Curiosity mediu a radiação na superfície de Gale.

### Mecânica (detalhe na spec)

- **Três barras:** energia, oxigênio e margem de radiação. Cheia é bom, vazia é perigo, e cada uma leva ícone, texto e número. O **medidor de radiação** fica separado das barras, com dois limiares: atenção e ir para o abrigo.
- **Cada sol tem duas fases:**
  - **plano**: sem relógio, e todo o texto do jogo mora aqui;
  - **turno**: de 60 a 90 s em tempo real, só clique, com uma lista de tarefas como a do Among Us.
- **A troca com custo (fechada hoje, 14/11):**
  - a energia que sobra do plano vai **sozinha** para a bateria, e não existe botão "guardar";
  - a bateria tem **teto**, e o excedente se perde;
  - o O2 produzido a mais fica no tanque como reserva;
  - o **aquecimento da noite** sai da energia todo sol, antes do plano e sem escolha. É ele que dá função à bateria na tempestade de poeira.
- **Eventos:** uma tempestade solar por missão, prevista pelo DONKI com dias de antecedência. Uma tempestade de poeira, sem aviso, com o sol de início sorteado entre 2 e 5. E a poeira que acumula no painel o tempo todo. Um evento por vez.
- **Modo de segurança:** entra quando falta energia para o aquecimento, o oxigênio acaba ou a margem de radiação zera. A tela explica a causa com um caso real. Se algum plano salva o sol, o botão é "o simulador reinicia o sol". Se nenhum salva, porque a causa veio de sóis anteriores, o botão é "seguir em modo de segurança".
- **Regra da calibração:** nenhuma estratégia pode ser melhor ou igual às outras duas em todos os cenários.
- **O que foi recusado, e por quê:** fim da spec, em "O que não faz".

### Ordem de construção e de corte

- **P0, hoje, o jogo inteiro e mínimo:** export Web no ar (feito), um cômodo com arte provisória, a fase de plano com as três barras, avançar sol, modo de segurança e relatório, a tempestade solar com o dado embutido e a tarefa do abrigo.
- **P1, hoje à noite e amanhã cedo:** tempestade de poeira e limpar o painel, consertar o gerador, ChemCam, sol 1 guiado, português e inglês, arte final.
- **P2, se sobrar:** amostra, planta, "Perguntar à Terra" e estática nas câmeras.
- Se atrasar, corta-se nesta ordem: planta → amostra → Perguntar à Terra → estática. **O P0 nunca se corta.** O código congela amanhã, horas antes do fim, para sobrar tempo para o vídeo de 30 s e o formulário.

## O que já está feito

- **Repo e deploy:** o esqueleto do Godot (640×360, Compatibility, preset Web sem threads) está no ar no GitHub Pages. `scripts/publicar.sh` exporta e publica. Funciona em qualquer máquina com o Godot 4.7.2 e os templates.
- **Troca com custo e números de partida:** estão numa página de calibração que simula as três estratégias em todos os sorteios da poeira, em https://claude.ai/artifact/BbJQ9PyK6rhk4C3jKahBzE. A página é privada: peça ao dono para compartilhar com você.
- **Pesquisa:** os números reais (O2 por pessoa, custo de energia do oxigênio, radiação em Gale, os casos do Opportunity e do InSight), o acesso aos dados da NASA (o DONKI responde sem chave e com CORS aberto) e o desenho para crianças de 7 a 12 anos estão nas notas do dono. A spec cita cada uma pelo nome; se precisar do detalhe, peça.

## Em andamento agora

- **Protótipo A, com o dono:** o cômodo gerado por script no Blender virando pixel art, nos 4 estados. Os arquivos ficam em `arte/` e `assets/comodo/`.
- **Protótipo B, a câmera em falso 3D:** panorama, pan e shader, com o clique caindo no lugar certo. **Está na sua área pelo rascunho de funções**; combine com o dono se é você quem pega. Um ponto a testar: a pesquisa recomenda o stretch `canvas_items`, e o `project.godot` hoje está em `viewport`. Compare os dois com o shader antes de escolher.
- **Protótipo C, com o dono:** o wireframe das telas (título, plano, turno, modo de segurança, relatório, créditos), numa página para vocês alinharem.

## O que está em aberto, e é seu

- **Os números do jogo [P]:** máximos das barras, teto da bateria, valor do aquecimento, duração do turno. Os de partida estão na página de calibração.
- **As estrelas do relatório [P], que precisam de atenção.** Com os números de partida, "tudo em ciência" faz 7 a 9 de ciência com 1 modo de segurança na maioria dos sorteios, e a estratégia equilibrada faz 3 a 7 sem nenhum. Pela regra de estrelas de hoje, as duas ficam com 2 estrelas, e a criança aprende que arriscar compensa. Vale resolver antes de programar o relatório.
- **A interação e a dificuldade de cada tarefa [P].**
- **O nome do jogo [P].**

## O que está em aberto com o dono

- A divisão fina de quem faz o quê.
- O detalhe do atraso de comunicação e do botão "Perguntar à Terra".

## Regras do evento que mexem no trabalho

- **Tudo em inglês na submissão.** A demo é um vídeo de até 30 s ou até 7 slides; passou do limite, sai do julgamento.
- **Citar toda fonte:** código, imagem, fonte tipográfica, shader e dado de terceiros, com a licença, na tela de créditos do jogo. A licença do repo é MIT.
- **Uso de IA:** a submissão tem de dizer como a IA foi usada. Anote cada bloco de trabalho com IA numa linha em [uso-de-si.md](uso-de-si.md).
- **Nada de nome, voz ou imagem de menor de 18** no projeto ou no vídeo.
