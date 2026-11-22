# Benchmark de desempenho: antes × depois

Os testes rodaram no simulador de iPhone do GitHub Actions (macOS 15), com o app compilado em modo Release e os mesmos dados nos dois casos: 365 pesagens, 30 medições, 150 treinos, 2.160 alimentos registrados e 300 alimentos salvos.

- **Antes:** commit `90271c7`, branch `bench-baseline`.
- **Depois:** `main`.

Cada teste foi repetido 7 vezes e o valor de cada rodada é a mediana dessas 7. Rodei duas vezes de cada lado e a tabela mostra a média das duas rodadas. A variação entre as máquinas do GitHub é de cerca de ±20%.

| # | Operação (o que o app faz) | Antes (ms) | Depois (ms) | Ganho |
|---|---|---:|---:|---:|
| 01 | Análise corporal completa (30 pesagens × 80 métricas) | 53,0 | 2,7 | **19×** |
| 02 | Tela Métricas: todas as métricas + progresso até a meta | 308,0 | 1,5 | **207×** |
| 03 | Gráfico histórico de uma métrica (365 pesagens) | 468,1 | 33,5 | **14×** |
| 04 | Medidas mescladas por data (120 consultas) | 173,4 | 155,3 | 1,1× |
| 05 | Busca de alimentos (10 buscas, 2.589 itens) | 35,8 | 31,8 | 1,1× (dentro da variação) |
| 06 | Melhores fontes de nutrientes (5 nutrientes) | 16,9 | 0,002 | **guardado em cache** |
| 07 | Busca de exercícios (8 buscas) | 4,0 | 1,8 | **2,1×** |
| 08 | Recordes e "última vez" no treino (6 exercícios × 150 treinos) | 201,3 | 12,1 | **17×** |
| 09 | Estatísticas de treino (volume, calorias, séries por músculo) | 116,5 | 7,3 | **16×** |
| 10 | Filtro de alimentos de 14 dias (só a operação bruta) | 165,6 | 182,8 | sem mudança* |
| 11 | Lista de alimentos salvos (300) | 9,3 | 1,1 | **8×** |
| 12 | Metas nutricionais (10 cálculos) | 29,6 | 15,3 | **1,9×** |

\* O teste 10 mede o filtro bruto, que continua igual. A tela de Alimentação **não faz mais esse filtro a cada redesenho**: o resultado fica guardado até um registro mudar, e esse ganho não aparece neste teste.

## O que foi otimizado

1. **Análise corporal com cache:** antes, cada `análise[.imc]` recalculava as ~80 métricas. Agora elas são calculadas uma vez por análise.
2. **`AnalysisContext` com cache:** `current`, `start`, `goal` e a análise de cada pesagem são calculados uma vez. As medidas viram uma linha do tempo com busca binária, em vez de criar objetos do banco a cada pesagem.
3. **Cache de JSON:** treinos, rotinas e alimentos salvos guardam dados em JSON, que era decodificado a cada leitura. Agora o cache é indexado pelo próprio conteúdo, então nunca devolve dado desatualizado.
4. **Recordes e "última vez":** uma única passada pelo histórico, em vez de ordenar todos os treinos para cada exercício.
5. **Média móvel de 7 dias:** janela deslizante, O(n) em vez de O(n²).
6. **Busca de exercícios e de alimentos:** os textos normalizados e as chaves de ordenação são calculados uma vez.
7. **Melhores fontes de cada nutriente:** o banco de alimentos não muda, então o ranking é calculado uma vez só.
8. **Tela de Alimentação:** guarda os registros do dia e as metas até os dados mudarem. A faixa de 14 dias agrupa os registros uma vez, em vez de filtrar a lista inteira para cada dia.
9. **Busca de alimentos na tela:** os resultados são calculados uma vez por atualização, e o "alimento salvo" de cada linha é encontrado por dicionário, não por busca linear.

## Bugs corrigidos

- **Recorde de volume errado:** o "maior volume" de um exercício só era atualizado quando a série também batia o recorde de 1RM.
- **NaN e infinito nos gráficos:** divisões por meta zero geravam NaN, que podia quebrar o desenho dos anéis, das barras e das faixas. Agora isso é protegido.
- **Medidas fora da análise atual**, quando tinham sido registradas depois da última pesagem (corrigido na versão anterior e mantido aqui).
