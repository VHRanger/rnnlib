# rnnlib
A library for recurrent neural networks in [Dlang](https://dlang.org/)

The aim of this project is to build a RNN factory such that one can construct
RNN architecture using simple layers and any non linear function.

The neural networks will primarily be trained using [Evolutionnary Algorithms](https://en.wikipedia.org/wiki/Evolutionary_algorithm).
The reason why we do not use any optimization based on gradient descent is to avoid many issues it gives us when optimizing
a rnn like vanishing/exploding gradients (e.g. see _[On the difficulty of training recurrent neural networks](http://www.jmlr.org/proceedings/papers/v28/pascanu13.pdf)_).

One of the auxiliary goal of this project is to cut any dependencies between the evolutionary algorithms
and the recurrent neural netwroks to enable anyone to use it independently.

## Daily Todo
* Think about parameters shared between layers: can the layer be different and share the same parameters ?
* (optm) randclone weigths: serialized_data holds all weigths -> can be constructed using smaller array with random cloning.


# TODO
* RNN
  * _Matrices_
    * Optimization
      * Use a single "dot" product and optimize it.
      * Matrix abstract multiplication: mult(auto override this T)
  * _Vectors_
    * Optimization
      * alias array for vector ?
      * use arrayfire ? 
  * _Layers_
    * ~Linear~
    * ~Functional~
    * ~Recurrent~
  * _Neural Network_
    * 
* TRAINING
  * _Evolutionary Algorithms_
    * Evolution Strategy
    * Genetic Algorithm
    * Particle Swarm optimization
    * Ant colony optimization
  * _Other Gradient-free Optimization_
    * Nelder–Mead Simplex
    * DIRECT
    * DONE
    * Pattern Search
    * MCS
* TESTS
  * _Functional Tests_
    * [Some good examples](https://en.wikipedia.org/wiki/Test_functions_for_optimization)
  * _Visualizable Tests_
    * test the optimization algorithm for drawing graphs: force directed layout gives a function.
  * _Machine Learning Tests_
    * Adding Problem
    * XOR
    * Copying memory
    * Pixel-by-pixel MNIST (+ permuted)
    * NLP ?
    * Music Generation ?
  * _Deep Reinforcement Learning Final Tests_
    * [Gym](https://gym.openai.com/)
    * [Universe](https://github.com/openai/universe)
    * Zbaghul
* DOCUMENTATION
  * Vector
  * Matrix
  * Layer
  * Neural Network
  * Optimization Algorithms
    * EA
    * OGFO
* FORMAT
  * CodeCov
  * Travis CI ?
  * [Command Line git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) (+ .gitignore)
  * dub
  * [For most of these](https://github.com/libmir/mir-algorithm)

