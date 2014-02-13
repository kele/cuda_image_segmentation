cuda_image_segmentation
=======================

Simple CUDA image segmentation implementation

--

Compilation
make - build the project
make debug - build the project (debug version)
make clean - clean the directory from project files

--

Usage: [n | g | c] flow image.ppm
    n - normalize the image (output is written to _image.ppm)
    g - use GPU (CUDA)
    c - use CPU
The result image is written to Simage.ppm

--

./data contains some example pictures to play with
