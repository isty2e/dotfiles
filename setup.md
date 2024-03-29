# Settings

## dotfiles

```bash
git clone https://github.com/tarjoilija/zgen
ln -s dotfiles/.zshrc ~/.zshrc
ln -s dotfiles/.zshrc_linux ~/.zshrc
ln -s dotfiles/.vimrc ~/.vimrc
ln -s dotfiles/.vim ~/.vim
```

## brew

```bash
brew install zsh vim neovim cmake git bazel fzf fd julia go crystal openssh pandoc nodejs ack the_silver_searcher r rstudio rbenv brave-browser visual-studio-code textmate xquartz brewsci/bio/pymol
```

## conda

[Mambaforge download](https://github.com/conda-forge/miniforge)

```bash
# general
mamba install altair plotnine black cython flake8 isort parmap pynvim pyarrow
# science
mamba install openmm mdtraj parmed oddt rdkit molvs mordred deepchem cmcrameri colorcet ambertools
mamba install -c omnia openforcefield openforcefields
# ML, cuda dependent
mamba install -c pytorch pytorch torchvision
mamba install -c pyg pytorch-scatter pytorch-sparse pytorch-cluster pytorch-spline-conv pyg
mamba install -c rapidsai cudf cuml
mamba install einops opt_einsum scikit-learn pytorch-lightning optuna
```
