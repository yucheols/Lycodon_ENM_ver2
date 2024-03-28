# Ecological niche modeling for the Red-banded Snake (Lycodon rufozonatus)
A MaxEnt ecological niche modeling workflow in R to assess the habitat suitability of Red-banded snakes (Lycodon rufozonatus) in Jeju Island, Republic of Korea.

![cover](https://github.com/yucheols/Lycodon_ENM_ver2/assets/85914125/06b06949-4ca1-4504-a7c8-0a56e2cf880f)

![Fig4](https://github.com/yucheols/Lycodon_ENM_ver2/assets/85914125/3deff1f3-70c3-46c3-ae22-ace96ef00b84)


## Study background
- The Red-banded Snake (Lycodon rufozonatus) is a colubrid with broad geographic distribution across East and Southeast Asia.
- In the Republic of Korea (South Korea), this species is commonly found across the mainland as well as on some of the islands that are close to the mainland.
- However, this species was well-known to be absent from the largest island of the country: Jeju. This was established by more than three decades of field surveys across South Korea.
- In July 2021, we found a roadkill of L. rufozonatus while conducting field surveys in Seogwipo, Jeju Island.
- As it was unlikely that this specimen represented a previously unknown island population, we determined its potential geographic origin through phylogenetic analyses of the mitochondrial COI and Cytb genes.
- We then assessed the habitat suitability of L. rufozonatus in Jeju using ecological niche modeling. The code and dataset are provided here to reproduce the results of niche modeling.

## Dataset
- The "occs.zip" file contains the raw and spatially rarefied occurrence points (15km thinning distance) of L. rufozoantus.
- The "bg.zip" file contains two sets of background points for MaxEnt modeling at two different spatial scales.
- The environmental data layers can be obtained and processed using the details provided in the paper (see below for citation).

## Citation
A research article associated with this project is published in the journal Herpetologica.

```
Y Shin, K Heo, SN Othman, Y Jang, M-S Min, A Borzée. 2024. Tracing the geographic origin of a non native Red
banded Snake (Colubridae: Lycodon rufozonatus) found on Jeju Island, Republic of Korea. Herpetologica 80: 30-39.
```

