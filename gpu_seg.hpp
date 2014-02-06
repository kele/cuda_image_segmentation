#ifndef __GPU_SEG_H__
#define __GPU_SEG_H__

#define INF 0x1ffffffe

#define MIN(a, b) (((a)>(b))?(b):(a))
#define MAX(a, b) (((a)<(b))?(b):(a))

#define BLOCK_WIDTH 32
#define BLOCK_HEIGHT 4
#define TILE_THREADS (BLOCK_WIDTH*BLOCK_HEIGHT)
#define PIXELS_PER_THREAD 8
#define TILE_SIZE (TILE_THREADS*PIXELS_PER_THREAD)

#define BLOCK_DATA_START_PTR(what) (&(what)[TILE_SIZE*(gridx*blockIdx.y + blockIdx.x)])
#define THREAD_DATA_OFFSET_PTR(what) (&(what)[threadIdx.y*BLOCK_WIDTH + threadIdx.x])
#define NEXT_PTR(what) (what + TILE_THREADS)

// This is used to retrieve from a local block.
#define LOCAL_XY(x, y) (((x)/8)*32 + (y) + ((x) % 8)*128)
#define GLOBAL_XY(a, b) ((TILE_SIZE*(gridx*((b)/32) + ((a)/32))) +  LOCAL_XY((a) % 32, (b) % 32))

#define VTHREAD_DATA_OFFSET_PTR(what) (&(what)[(threadIdx.x/8)*BLOCK_WIDTH + (threadIdx.y*8)])
#define VNEXT_PTR(what) (what + 1)

void __global__ gpu_push(int *global_e, int *global_h, int *right_edges,
  int *left_edges, int *up_edges, int *down_edges, int *to_source, int *to_sink);

void __global__ gpu_relabel(int *global_e, int *global_h, int *right_edges,
  int *left_edges, int *up_edges, int *down_edges, int *to_source, int *to_sink);

#endif
