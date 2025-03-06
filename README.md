# Coastal Wetlands Ecosystem Services Valuation

This repository contains the code and resources used for the global valuation of coastal wetlands, focusing on the economic benefits provided by these ecosystems, particularly through avoided damages for coastal protection services. We employ two primary methods to estimate the value of coastal wetland ecosystem services:

1. **Avoided damages using DIVA**: The Dynamic Interactive Vulnerability Assessment (DIVA) model [^1] is used to quantify the avoided damages associated with the loss of coastal protection services provided by wetlands. By estimating the economic value lost when coastal wetlands are reduced, we can assess the impact on global welfare and specific countries' economies.
[^1]: DIVA model web page https://globalclimateforum.org/portfolio-item/diva-model/
2. **Meta-Regression Benefit Transfer**: This method estimates the demand for ecosystem services across different regions globally. It is particularly useful for marginal valuation analyses and assessing trade-offs among multiple ecosystem services. The meta-regression model helps to generalize findings from similar studies conducted in various contexts, providing a robust basis for benefit transfer across countries and ecosystems.

## Repository Contents

### Models and Methods

1. **Avoided Damages Method (DIVA Model)**: This section contains the implementation of the DIVA model [^2] used to estimate economic losses associated with reduced coastal wetlands. The model inputs environmental data, socioeconomic factors and calculates potential damages avoided by maintaining wetland areas.
[^2]: DIVA library https://gitlab.com/globalclimateforum/diva_library

3. **Meta-Regression Benefit Transfer**: This includes code and documentation for conducting meta-regressions to transfer benefits from similar studies across different regions globally. It helps in understanding the demand for coastal wetlands ecosystem services under various scenarios of reduction.

### Data Sources

The repository integrates a variety of data sources including:

- **Coastal Wetlands Data**: State-of-the-art remote sense dataset for mangroves [^3], saltmarshes [^4] and tidalflats [^5].
[^3]: Bunting, P., Rosenqvist, A., Hilarides, L., Lucas, R. M., Thomas, N., Tadono, T., Worthington, T. A., Spalding, M., Murray, N. J., and Rebelo, L.-M. (2022). Global mangrove extent change 1996-2020: Global mangrove watch version 3.0. Remote Sensing, 14(15). https://doi.org/10.3390/rs14153657
[^4]: Mcowen C, Weatherdon L, Bochove J, Sullivan E, Blyth S, Zockler C, Stanwell-Smith D, Kingston N, Martin C, Spalding M, Fletcher S (2017) A global map of saltmarshes. Biodiversity Data Journal 5: e11764. https://doi.org/10.3897/BDJ.5.e11764
[^5]: Murray, N.J., Phinn, S.R., DeWitt, M. et al. The global distribution and trajectory of tidal flats. Nature 565, 222–225 (2019). https://doi.org/10.1038/s41586-018-0805-8
- **Previous Local Case Studies**: A comprehensive literature review is conducted to build a database of studies that have quantified the benefits of coastal wetlands globally. We used the Ecosystem Services Valuation Database (ESVD) [^6] which simplified significantly the collection effort.
[^6]: Brander, L.M. de Groot, R, Guisado Goñi, V., van 't Hoff, V., Schägner, P., Solomonides, S., McVittie, A., Eppink, F., Sposato, M., Do, L., Ghermandi, A., and Sinclair, M. (2024). Ecosystem Services Valuation Database (ESVD). Foundation for Sustainable Development and Brander Environmental Economics. https://www.esvd.net/esvd
- **Socioeconomic Data**: Population data from Global Human Settlement Layer [^7], gridded GDP data [^8].
[^7]: https://human-settlement.emergency.copernicus.eu/datasets.php
[^8]: https://datadryad.org/stash/dataset/doi:10.5061/dryad.dk1j0
- **Geographic Data**: Digital elevation data from meritDEM [^9].
[^9]: https://hydro.iis.u-tokyo.ac.jp/~yamadai/MERIT_DEM/
- **Extreme surge data**: Extreme water level data from COAST-RP data [^10].
[^10]: https://data.4tu.nl/articles/dataset/COAST-RP_A_global_COastal_dAtaset_of_Storm_Tide_Return_Periods/13392314

### Visualization and Analysis Tools

- **Data Visualization**: Graphs, maps, and charts are used to illustrate how wetland area reductions impact economic welfare globally and country-wise.
- **Statistical Analysis**: R and Julia scripts for statistical tests (e.g., meta-analysis) that help in validating the models' results and drawing meaningful insights from the data.

### Usage

The repository is designed to reproduce the analysis of global coastal wetlands ecosystem services valuation, also allowing users to:

- Run analyses on different scenarios of coastal wetland reduction.
- Run the sensitivity analysis by choosing different wetlands attenuation rates.
- Extend the methods by incorporating new datasets or refining existing models.
- Visualize results using the provided tools or through custom scripts.

## Getting Started

To get started with this repository it is essential to use the DIVACoast.jl library [^2], please refer to the detailed documentation [^12] and the main README file within this repository. The DIVACoast.jl documentation includes installation instructions, usage guidelines and examples of how to run analyses.
[^12]: https://globalclimateforum.gitlab.io/DIVACoast.jl/

## Contributing

We welcome contributions from researchers and developers interested in advancing the field of coastal wetlands valuation. To contribute:

1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Make changes and test them thoroughly.
4. Submit a pull request with detailed explanations of your modifications.

## Contact

For questions, feedback, or to report issues, please open an issue in the repository. For more technical discussions, you can reach out to the maintainers via email or other communication channels provided on our project page.

---

This readme file provides a structured overview of the purpose and functionality of the repository, aimed at facilitating understanding for potential users, contributors and collaborators interested in coastal wetlands ecosystem services valuation and for the reproducibility of scientific research.
