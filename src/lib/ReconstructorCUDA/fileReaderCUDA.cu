
#include "fileReaderCUDA.cuh"
#include "CUDA_Error.cuh"

namespace SLS
{
__global__ void computeMask_kernel(
        unsigned char *brightImg,
        unsigned char *darkImg,
        uchar blackThreashold,
        size_t resX,
        size_t resY,
        Dynamic_Bitset_Array_GPU mask
        )
{
    uint idx = blockIdx.x*blockDim.x + threadIdx.x;
    uint stride = blockDim.x * gridDim.x;
    //const size_t BITS_PER_BYTE = mask.BITS_PER_BYTE;
    while (idx < resX*resY)
    {
        uchar b = brightImg[idx];
        uchar d = darkImg[idx];
        if (b - d > blackThreashold)
            mask.setBit(0,idx);
        else
            mask.clearBit(0,idx);
        idx += stride;
    }
}
void FileReaderCUDA::computeShadowsAndThreasholds()
{
    cv::Mat& brightImg=images_[0];
    cv::Mat& darkImg=images_[1];
    unsigned char *brightImg_d=nullptr;
    unsigned char *darkImg_d=nullptr;

    gpuErrchk( cudaMalloc( (void**)&brightImg_d, sizeof(uchar)*brightImg.cols*brightImg.rows));
    gpuErrchk( cudaMalloc( (void**)&darkImg_d, sizeof(uchar)*darkImg.cols*darkImg.rows));
    //Check if continous
    if (brightImg.isContinuous() && darkImg.isContinuous())
    {
        gpuErrchk(cudaMemcpy( brightImg_d, brightImg.data, sizeof(uchar)*brightImg.rows*brightImg.cols, cudaMemcpyHostToDevice));
        gpuErrchk(cudaMemcpy( darkImg_d, darkImg.data, sizeof(uchar)*darkImg.rows*darkImg.cols, cudaMemcpyHostToDevice));
    }
    else
    {
        LOG::writeLogErr("images are not continuous!\n");
        exit(0);
    }

    // Intialize maskGPU_
    maskGPU_ = new Dynamic_Bitset_Array(brightImg.rows*brightImg.cols, 1);
    computeMask_kernel<<<200,200>>> (
            brightImg_d, darkImg_d, 
            blackThreshold_,
            resX_, resY_,
            maskGPU_->getGPUOBJ());
    gpuErrchk( cudaPeekAtLastError());
    maskGPU_->writeToPGM(name_+"_mask.pgm", resX_, resY_, false, 1);

    // Clean up
    gpuErrchk(cudaFree(brightImg_d));
    gpuErrchk(cudaFree(darkImg_d));
}
} // namespace SLS
