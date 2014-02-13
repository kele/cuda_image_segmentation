#include <cstdio>
#include <cstring>
#include <deque>
#include <vector>

#include "gpu_seg.hpp"
#include "cpu_seg.hpp"
#include "cpu_utils.hpp"

/*
 * TODO:
 * - debug
 * - use reduction on excess flow to effectively limit the number of iterations
 */


///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
void __global__ gpu_init(int *global_e, int *to_source, int gridx, int gridy)
{
    int *e = THREAD_DATA_OFFSET_PTR(BLOCK_DATA_START_PTR(global_e));
    int *src_edg_ptr = THREAD_DATA_OFFSET_PTR(BLOCK_DATA_START_PTR(to_source));
    int src_edg;

    for (int i = 0; i < 8; i++) {
        src_edg = *src_edg_ptr;

        *src_edg_ptr = 2*src_edg;     // writeback
        *e = src_edg;                 // writeback

        e = NEXT_PTR(e);
        src_edg_ptr = NEXT_PTR(src_edg_ptr);
    }
}

void __global__ gpu_push_horiz_tiles(int *global_e, int *global_h, int *right_edges,
  int *left_edges, int gridx, int gridy)
{
        int current_h = global_h[GLOBAL_XY(threadIdx.x*32, threadIdx.y)];
        int current_e = global_e[GLOBAL_XY(threadIdx.x*32, threadIdx.y)];
        int next_h = global_h[GLOBAL_XY((threadIdx.x + 1)*32, threadIdx.y)];
        int next_e = global_e[GLOBAL_XY((threadIdx.x + 1)*32, threadIdx.y)];

        int right_edge = right_edges[GLOBAL_XY(threadIdx.x*32, threadIdx.y)];
        int left_edge = left_edges[GLOBAL_XY(threadIdx.x*32, threadIdx.y)];

        int delta = 0;
        if (current_h > next_h)
            delta = MIN(right_edge, current_e);
        else if (current_h < next_h)
            delta = -MIN(left_edge, next_e);
        right_edge  -= delta;
        current_e   -= delta;
        left_edge   += delta;
        next_e      += delta;

        if (threadIdx.x != gridx - 1) {
            right_edges[GLOBAL_XY(threadIdx.x*32, threadIdx.y)] = right_edge;
            left_edges[GLOBAL_XY(threadIdx.x*32, threadIdx.y)] = left_edge;
            global_e[GLOBAL_XY(threadIdx.x*32, threadIdx.y)] = current_e;
            global_e[GLOBAL_XY((threadIdx.x + 1)*32, threadIdx.y)] = next_e;
        }
}
void __global__ gpu_push_vertical_tiles(int *global_e, int *global_h, int *down_edges,
  int *up_edges, int gridx, int gridy)
{
        int current_h = global_h[GLOBAL_XY(threadIdx.x, threadIdx.y*32)];
        int current_e = global_e[GLOBAL_XY(threadIdx.x, threadIdx.y*32)];
        int next_h = global_h[GLOBAL_XY(threadIdx.x, (threadIdx.y + 1)*32)];
        int next_e = global_e[GLOBAL_XY(threadIdx.x, (threadIdx.y + 1)*32)];

        int down_edge = down_edges[GLOBAL_XY(threadIdx.x, threadIdx.y*32)];
        int up_edge = up_edges[GLOBAL_XY(threadIdx.x, threadIdx.y*32)];

        int delta = 0;
        if (current_h > next_h)
            delta = MIN(down_edge, current_e);
        else if (current_h < next_h)
            delta = -MIN(up_edge, next_e);
        down_edge  -= delta;
        current_e   -= delta;
        up_edge   += delta;
        next_e      += delta;

        if (threadIdx.y != gridy - 1) {
            down_edges[GLOBAL_XY(threadIdx.x, threadIdx.y*32)] = down_edge;
            up_edges[GLOBAL_XY(threadIdx.x, threadIdx.y*32)] = up_edge;
            global_e[GLOBAL_XY(threadIdx.x, threadIdx.y*32)] = current_e;
            global_e[GLOBAL_XY(threadIdx.x, (threadIdx.y + 1)*32)] = next_e;
        }
}

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
void __global__ gpu_push(int *global_e, int *global_h, int *right_edges,
  int *left_edges, int *up_edges, int *down_edges, int *to_source, int *to_sink, int gridx, int gridy)
{
    extern __shared__ int shared[];
    int *e = THREAD_DATA_OFFSET_PTR(&shared[0]);
    int *h = THREAD_DATA_OFFSET_PTR(&shared[32*32]);
    
    int *tmp_e = THREAD_DATA_OFFSET_PTR(BLOCK_DATA_START_PTR(global_e));
    int *tmp_h = THREAD_DATA_OFFSET_PTR(BLOCK_DATA_START_PTR(global_h));

    for (int i = 0; i < 8; i++) {
        *e = *tmp_e;
        *h = *tmp_h;
        e = NEXT_PTR(e); tmp_e = NEXT_PTR(tmp_e);
        h = NEXT_PTR(h); tmp_h = NEXT_PTR(tmp_h);
    }
    __syncthreads();


    int delta;
    int current_h, current_e;
    int next_h, next_e;
    int *right_edge_ptr, *left_edge_ptr;
    int right_edge, left_edge;

///////////////////////////////////////////////////////////////////////////////
    /* horizontal push */
    e = THREAD_DATA_OFFSET_PTR(&shared[0]);
    h = THREAD_DATA_OFFSET_PTR(&shared[32*32]);

    right_edge_ptr  = THREAD_DATA_OFFSET_PTR(BLOCK_DATA_START_PTR(right_edges));
    left_edge_ptr   = THREAD_DATA_OFFSET_PTR(BLOCK_DATA_START_PTR(left_edges));
    current_h = *h;
    current_e = *e;

    for (int i = 0; i < 7; i++) {
        next_h = *NEXT_PTR(h);
        next_e = *NEXT_PTR(e);

        right_edge = *right_edge_ptr;
        left_edge = *left_edge_ptr;

        if (current_h > next_h)
            delta = MIN(right_edge, current_e);
        else if (current_h < next_h)
            delta = -MIN(left_edge, next_e);
        else
            delta = 0;
        right_edge  -= delta;
        current_e   -= delta;
        left_edge   += delta;
        next_e      += delta;

        /* write back */
        *right_edge_ptr = right_edge;
        *left_edge_ptr = left_edge;
        *e = current_e;

        current_h = next_h;
        current_e = next_e;
        e = NEXT_PTR(e);
        h = NEXT_PTR(h);
        
        right_edge_ptr = NEXT_PTR(right_edge_ptr);
        left_edge_ptr = NEXT_PTR(left_edge_ptr);
    }
    
    __syncthreads();

    /* 8th iteration */
    if (threadIdx.y != BLOCK_HEIGHT - 1) {
        next_h = (&shared[32*32])[LOCAL_XY((threadIdx.y + 1)*8, threadIdx.x)];
        next_e = (&shared[0])[LOCAL_XY((threadIdx.y + 1)*8, threadIdx.x)];

        right_edge = *right_edge_ptr;
        left_edge = *left_edge_ptr;

        if (current_h > next_h)
            delta = MIN(right_edge, current_e);
        else if (current_h < next_h)
            delta = -MIN(left_edge, next_e);
        else
            delta = 0;
        right_edge  -= delta;
        current_e   -= delta;
        left_edge   += delta;
        next_e      += delta;
        
        /* write back */
        *right_edge_ptr = right_edge;
        *left_edge_ptr = left_edge;
        *e = current_e;
        (&shared[0])[LOCAL_XY((threadIdx.y + 1)*8, threadIdx.x)] = next_e;

    } 
    // sync delayed... (a)

///////////////////////////////////////////////////////////////////////////////
    /*
     * vertical push
     * NOTE: Unfortunately, I have found no way to avoid bank conflicts in the vertical push. Too bad :(
     */
    /* edges are read normally, it changes only for e and h */
    e = VTHREAD_DATA_OFFSET_PTR(&shared[0]);
    h = VTHREAD_DATA_OFFSET_PTR(&shared[32*32]);

    right_edge_ptr = VTHREAD_DATA_OFFSET_PTR(BLOCK_DATA_START_PTR(down_edges));
    left_edge_ptr =  VTHREAD_DATA_OFFSET_PTR(BLOCK_DATA_START_PTR(up_edges));

    __syncthreads(); // here! (a)

    current_h = *h;
    current_e = *e;

    for (int i = 0; i < 7; i++) {
        next_h = *VNEXT_PTR(h);
        next_e = *VNEXT_PTR(e);

        right_edge = *right_edge_ptr;
        left_edge = *left_edge_ptr;

        if (current_h > next_h)
            delta = MIN(right_edge, current_e);
        else if (current_h < next_h)
            delta = -MIN(left_edge, next_e);
        else
            delta = 0;
        right_edge  -= delta;
        current_e   -= delta;
        left_edge   += delta;
        next_e      += delta;
        
        /* write back */
        *right_edge_ptr = right_edge;
        *left_edge_ptr = left_edge;
        *e = current_e;

        current_h = next_h;
        current_e = next_e;
        e = VNEXT_PTR(e);
        h = VNEXT_PTR(h);
        
        right_edge_ptr = VNEXT_PTR(right_edge_ptr);
        left_edge_ptr = VNEXT_PTR(left_edge_ptr);
    }
    
    __syncthreads();

    /* 8th iteration */
    if (threadIdx.y != BLOCK_HEIGHT - 1) {
        next_h = *VNEXT_PTR(h);
        next_e = *VNEXT_PTR(e);

        right_edge = *right_edge_ptr;
        left_edge = *left_edge_ptr;

        if (current_h > next_h)
            delta = MIN(right_edge, current_e);
        else if (current_h < next_h)
            delta = -MIN(left_edge, next_e);
        else
            delta = 0;
        right_edge  -= delta;
        current_e   -= delta;
        left_edge   += delta;
        next_e      += delta;
        
        /* write back */
        *right_edge_ptr = right_edge;
        *left_edge_ptr = left_edge;
        *e = current_e;
        *VNEXT_PTR(e) = next_e;
    }
    __syncthreads();

    
///////////////////////////////////////////////////////////////////////////////
    /* source push */
    e = THREAD_DATA_OFFSET_PTR(&shared[0]);
    h = THREAD_DATA_OFFSET_PTR(&shared[32*32]);

    right_edge_ptr = THREAD_DATA_OFFSET_PTR(BLOCK_DATA_START_PTR(to_source));

    for (int i = 0; i < 8; i++) {
        current_h = *h;
        current_e = *e;

        right_edge = *right_edge_ptr;

        if (current_h > 32*32*gridx*gridy)
            delta = MIN(right_edge, current_e);
        else
            delta = 0;
        right_edge  -= delta;
        current_e   -= delta;
        
        /* write back */
        *right_edge_ptr = right_edge;
        *e = current_e;

        e = NEXT_PTR(e);
        h = NEXT_PTR(h);
        right_edge_ptr = NEXT_PTR(right_edge_ptr);
    }

    /* NO NEED TO SYNC HERE */

///////////////////////////////////////////////////////////////////////////////
    /* sink push */
    e = THREAD_DATA_OFFSET_PTR(&shared[0]);
    h = THREAD_DATA_OFFSET_PTR(&shared[32*32]);

    right_edge_ptr = THREAD_DATA_OFFSET_PTR(BLOCK_DATA_START_PTR(to_sink));

    for (int i = 0; i < 8; i++) {
        current_h = *h;
        current_e = *e;

        right_edge = *right_edge_ptr;

        if (current_h > 0)
            delta = MIN(right_edge, current_e);
        else
            delta = 0;
        right_edge  -= delta;
        current_e   -= delta;
        
        /* write back */
        *right_edge_ptr = right_edge;
        *e = current_e;

        e = NEXT_PTR(e);
        h = NEXT_PTR(h);
        right_edge_ptr = NEXT_PTR(right_edge_ptr);
    }

    __syncthreads();
    
///////////////////////////////////////////////////////////////////////////////
    /* write back */
    e = THREAD_DATA_OFFSET_PTR(&shared[0]);
    tmp_e = THREAD_DATA_OFFSET_PTR(BLOCK_DATA_START_PTR(global_e));
    for (int i = 0; i < 8; i++) {
        *tmp_e = *e;
        e = NEXT_PTR(e);
        tmp_e = NEXT_PTR(tmp_e);
    }
}

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
/* run this 32x32 */
void __global__ gpu_relabel(int *global_e, int *global_h, int *right_edges,
  int *left_edges, int *up_edges, int *down_edges, int *to_source, int *to_sink, int gridx, int gridy)
{
    int x = blockIdx.x*32 + threadIdx.x;
    int y = blockIdx.y*32 + threadIdx.y;

    int h = global_h[GLOBAL_XY(x, y)];

    int down = (y < 32*gridy - 1) ? down_edges[GLOBAL_XY(x, y)] : 0;
    int left = (x > 0) ? left_edges[GLOBAL_XY(x, y)] : 0;
    int right = (x < 32*gridx - 1) ? right_edges[GLOBAL_XY(x, y)] : 0;
    int up = (y > 0) ? up_edges[GLOBAL_XY(x, y)] : 0;
    int sink = to_sink[GLOBAL_XY(x, y)];
    int source = to_source[GLOBAL_XY(x, y)];

    int min_height = INF;
    int relabel = global_e[GLOBAL_XY(x, y)] > 0;

    if (down > 0) {
        int hdown = global_h[GLOBAL_XY(x, y+1)];
        if (h > hdown)
            relabel = 0;
        min_height = MIN(min_height, hdown);
    }
    if (up > 0) {
        int hup = global_h[GLOBAL_XY(x, y-1)];
        if (h > hup)
            relabel = 0;
        min_height = MIN(min_height, hup);
    }
    if (left > 0) {
        int hleft = global_h[GLOBAL_XY(x - 1, y)];
        if (h > hleft)
            relabel = 0;
        min_height = MIN(min_height, hleft);
    }
    if (right > 0) {
        int hright = global_h[GLOBAL_XY(x+1, y)];
        if (h > hright)
            relabel = 0;
        min_height = MIN(min_height, hright);
    }
    if (source > 0) {
        if (h > 32*32*gridx*gridy)
            relabel = 0;
        min_height = MIN(min_height, 32*32*gridx*gridy);
    }
    if (sink > 0) {
        if (h > 0)
            relabel = 0;
        min_height = MIN(min_height, 0);
    }

    __syncthreads();

    if (relabel && min_height != INF)
        global_h[GLOBAL_XY(x, y)] = min_height + 1;
}


/* Image resolution is a multiplication of 32 */
void segmentation_gpu(int width, int height, const pixel_t *image,
  const pixel_t *marks, pixel_t *segmented_image)
{
    typedef ImageGraph::regular_node_t regular_node_t;
    typedef ImageGraph::node_t node_t;

    ImageGraph g(width, height);
    Histogram hist(width, height, image, marks);

    std::vector<bool> visited(height*width, false);
    std::deque<int> Q;



    /* REG_NEIGBHOURS, unfortunately, has to be 4 here */
    const int delt[ImageGraph::REG_NEIGHBOURS][2] = {
                {-1,  0},
      { 0, -1},           { 0, +1},
                {+1,  0}};

    /* neighbour edges */
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            regular_node_t &v = g.get(x, y);
            for (int i = 0; i < g.REG_NEIGHBOURS; i++) {
                if (in_range(y + delt[i][0], 0, height - 1) &&
                  in_range(x + delt[i][1], 0, width - 1)) {
                    const int dy = y + delt[i][0];
                    const int dx = x + delt[i][1];
                    regular_node_t &u = g.get(dx, dy);
                    v.c[i] = compute_edge(image[y*width + x], image[dy*width + dx]);
                }
            }
        }
    }

    /* source and sink edges */
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            regular_node_t &v = g.get(x, y);

            int k = 0;
            for (int i = 0; i < g.REG_NEIGHBOURS; i++)
                k = (k < v.c[i]) ? v.c[i] : k;
            k = k + 1;

            int i = y*width + x;
            if (marks[y*width + x] == WHITE) {
                v.c[g.SOURCE] = g.source.c[i] = k;
                v.c[g.SINK] = g.sink.c[i] = 0;
            } else if (marks[y*width + x] == BLACK) {
                v.c[g.SINK] = g.sink.c[i] = k;
                v.c[g.SOURCE] = g.source.c[i] = 0;
            } else {
                v.c[g.SOURCE] = MULT*LAMBDA*(-log(hist.prob_bg(image[i])));
                v.c[g.SINK] = MULT*LAMBDA*(-log(hist.prob_obj(image[i])));
                g.source.c[i] = v.c[g.SOURCE];
                g.sink.c[i] = v.c[g.SINK];
            }
        }
    }


    int *to_sink, *to_source, *up_e, *down_e, *right_e, *left_e;
    int *e, *h;
    to_sink = new int[width*height];
    to_source = new int[width*height];
    up_e = new int[width*height];
    down_e = new int[width*height];
    right_e = new int[width*height];
    left_e = new int[width*height];
    e = new int[width*height];
    h = new int[width*height];

    int gridx, gridy;

    gridx = width/32;
    gridy = height/32;
    for (unsigned x = 0; x < width; x++) {
        for (unsigned y = 0; y < height; y++) {
            to_sink[GLOBAL_XY(x, y)] = g.get(x, y).c[g.SINK];
            to_source[GLOBAL_XY(x, y)] = g.get(x, y).c[g.SOURCE];
            if (y != height - 1)
                up_e[GLOBAL_XY(x, y)] = g.get(x, y + 1).c[0];
            else
                up_e[GLOBAL_XY(x, y)] = 0;

            if (x != width - 1)
                left_e[GLOBAL_XY(x, y)] = g.get(x + 1, y).c[1];
            else
                left_e[GLOBAL_XY(x, y)] = 0;
            
            right_e[GLOBAL_XY(x, y)] = g.get(x, y).c[2];
            down_e[GLOBAL_XY(x, y)] = g.get(x, y).c[3];
            e[GLOBAL_XY(x, y)] = 0; 
            h[GLOBAL_XY(x, y)] = 0;
        }
    }

    int *cto_sink, *cto_source, *cup_e, *cdown_e, *cright_e, *cleft_e;
    int *ce, *ch;

    cudaMalloc(&cto_sink, width*height*sizeof(int));
    cudaMalloc(&cto_source, width*height*sizeof(int));
    cudaMalloc(&cup_e, width*height*sizeof(int));
    cudaMalloc(&cdown_e, width*height*sizeof(int));
    cudaMalloc(&cright_e, width*height*sizeof(int));
    cudaMalloc(&cleft_e, width*height*sizeof(int));
    cudaMalloc(&ce, width*height*sizeof(int));
    cudaMalloc(&ch, width*height*sizeof(int));

    cudaMemcpy(cto_sink, to_sink, width*height*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(cto_source, to_source, width*height*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(cup_e, up_e, width*height*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(cdown_e, down_e, width*height*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(cright_e, right_e, width*height*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(cleft_e, left_e, width*height*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(ce, e, width*height*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(ch, h, width*height*sizeof(int), cudaMemcpyHostToDevice);

    
    dim3 relabel_dim(32, 32);
    dim3 other_dim(32, 4);
    dim3 grid_dim(gridx, gridy);
    cudaError_t err;

    gpu_init<<<grid_dim, other_dim>>> (ce, cto_source, gridx, gridy);
    if (cudaSuccess != (err = cudaGetLastError())) {
        printf("#0 Error: %s\n", cudaGetErrorString(err));
        goto cleanup;
    }
    

    // TODO: change this O(w*h) loop into while(reduction())
    for (int i = 0; i < width*height; i++) {
        gpu_push<<<grid_dim, other_dim, 32*32*8>>>(ce, ch, cright_e, cleft_e,
          cup_e, cdown_e, cto_source, cto_sink, gridx, gridy);
        if (cudaSuccess != (err = cudaGetLastError())) {
            printf("#1 Error: %s\n", cudaGetErrorString(err));
            goto cleanup;
        }
        gpu_push_horiz_tiles<<<dim3(gridx, height), 1>>>(ce, ch, cright_e,
          cleft_e, gridx, gridy);
        if (cudaSuccess != (err = cudaGetLastError())) {
            printf("#2 Error: %s\n", cudaGetErrorString(err));
            goto cleanup;
        }
        gpu_push_vertical_tiles<<<dim3(width, gridy), 1>>>(ce, ch, cdown_e,
          cup_e, gridx, gridy);
        if (cudaSuccess != (err = cudaGetLastError())) {
            printf("#3 Error: %s\n", cudaGetErrorString(err));
            goto cleanup;
        }
        gpu_relabel<<<grid_dim, relabel_dim, 32*32*8>>>(ce, ch, cright_e,
          cleft_e, cup_e, cdown_e, cto_source, cto_sink, gridx, gridy);
        if (cudaSuccess != (err = cudaGetLastError())) {
            printf("#4 Error: %s\n", cudaGetErrorString(err));
            goto cleanup;
        }
    }


    cudaMemcpy(to_sink, cto_sink, width*height*sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(to_source, cto_source, width*height*sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(up_e, cup_e, width*height*sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(down_e, cdown_e, width*height*sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(right_e, cright_e, width*height*sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(left_e, cleft_e, width*height*sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(e, ce, width*height*sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(h, ch, width*height*sizeof(int), cudaMemcpyDeviceToHost);


    /* Copying back */
    for (unsigned x = 0; x < width; x++) {
        for (unsigned y = 0; y < height; y++) {
            g.get(x, y).c[g.SINK] = to_sink[GLOBAL_XY(x, y)];
            g.get(x, y).c[g.SOURCE] = to_source[GLOBAL_XY(x, y)];

            if (y > 0)
                g.get(x, y).c[0] = up_e[GLOBAL_XY(x, y - 1)];
            else
                g.get(x, y).c[0] = 0;
            
            if (x > 0)
                g.get(x, y).c[1] = left_e[GLOBAL_XY(x - 1, y)];
            else
                g.get(x, y).c[1] = 0;

            g.get(x, y).c[2] = right_e[GLOBAL_XY(x, y)];
            g.get(x, y).c[3] = down_e[GLOBAL_XY(x, y)];

            g.get(x, y).overflow = e[GLOBAL_XY(x, y)];
            g.get(x, y).height = h[GLOBAL_XY(x, y)];
            if (g.get(x, y).height > 0)
                printf("%d \t%d \t| overflow = %d \t| height = %d\n", x, y, g.get(x, y).overflow, g.get(x, y).height); // DEBUG
        }
    }
    /* Make the image white */
    for (int i = 0; i < height*width; i++) {
        segmented_image[i].r = 255;
        segmented_image[i].g = 255;
        segmented_image[i].b = 255;
    }

    for (unsigned i = 0; i < g.width*g.height; i++) {
        if (g.source.c[i] > 0) {
            segmented_image[i].r = image[i].r;
            segmented_image[i].g = image[i].g;
            segmented_image[i].b = image[i].b;
            Q.push_back(i);
            visited[i] = true;
        }
    }

    while (!Q.empty()) {
        int vpos = Q.front();
        Q.pop_front();

        const int x = vpos % width;
        const int y = vpos / width;
        regular_node_t &v = g.nodes[vpos];
        for (int i = 0; i < g.REG_NEIGHBOURS; i++) {
            if (in_range(y + delt[i][0], 0, height - 1) &&
              in_range(x + delt[i][1], 0, width - 1)) {

                if (v.c[i] <= 0)
                    continue;

                const int dy = y + delt[i][0];
                const int dx = x + delt[i][1];
                const int upos = dy*width + dx;
                if (visited[upos])
                    continue;

                segmented_image[upos].r = image[upos].r;
                segmented_image[upos].g = image[upos].g;
                segmented_image[upos].b = image[upos].b;
                Q.push_back(upos);
                visited[upos] = true;
            }
        }
    }

cleanup:
    cudaFree(cdown_e);
    cudaFree(ce);
    cudaFree(ch);
    cudaFree(cleft_e);
    cudaFree(cright_e);
    cudaFree(cto_sink);
    cudaFree(cto_source);
    cudaFree(cup_e);

    delete [] down_e;
    delete [] e;
    delete [] h;
    delete [] left_e;
    delete [] right_e;
    delete [] to_sink;
    delete [] to_source;
    delete [] up_e;
}
