#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdlib>
#include <deque>

#include "cpu_seg.hpp"

void push_relabel(ImageGraph &g);

void segmentation_cpu(int width, int height, const pixel_t *image,
  const pixel_t *marks, pixel_t *segmented_image)
{
    typedef ImageGraph::regular_node_t regular_node_t;
    typedef ImageGraph::node_t node_t;

    ImageGraph g(width, height);
    Histogram hist(width, height, image, marks);

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
    push_relabel(g);

    /* Make the image white */
    for (int i = 0; i < height*width; i++) {
        segmented_image[i].r = 255;
        segmented_image[i].g = 255;
        segmented_image[i].b = 255;
    }

    /* BFS */
    std::vector<bool> visited(height*width, false);
    std::deque<int> Q;
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
}

void push_relabel(ImageGraph &g)
{
    typedef ImageGraph::regular_node_t regular_node_t;
    typedef ImageGraph::node_t node_t;

    const int delt[ImageGraph::REG_NEIGHBOURS][2] = {
                {-1,  0},
      { 0, -1},           { 0, +1},
                {+1,  0}};

    /*
     * Push-relabel with FIFO queue.
     */
    std::deque<int> Q;

    /* initialise preflow */
    g.source.height = g.width * g.height;
    for (int i = 0; i < g.width * g.height; i++) {
        regular_node_t &v = g.nodes[i];
        const int d = g.source.c[i];
        g.source.overflow   -= d;
        g.source.c[i]       -= d;
        v.overflow          += d;
        v.c[g.SOURCE]       += d;
        Q.push_back(i);
    }
    g.sink.overflow = 0;


    /* main loop */
    while (!Q.empty()) {
        const int vpos = Q.front();
        regular_node_t &v = g.nodes[vpos];
        Q.pop_front();

        const int x = vpos % g.width;
        const int y = vpos / g.width;
        for (int i = 0; i < g.REG_NEIGHBOURS; i++) {
            if (in_range(y + delt[i][0], 0, g.height - 1) &&
              in_range(x + delt[i][1], 0, g.width - 1)) {
                const int dy = y + delt[i][0];
                const int dx = x + delt[i][1];
                const int upos = dy*g.width + dx;
                regular_node_t &u = g.nodes[upos];

                if (v.height > u.height && v.c[i] > 0) {
                // if (v.height == u.height + 1 && v.c[i] > 0) {
                    const int d = std::min(v.overflow, v.c[i]);
                    const int ui = g.REG_NEIGHBOURS - 1 - i;
                    v.overflow      -= d; 
                    v.c[i]          -= d;   
                    u.overflow      += d;
                    u.c[ui]         += d;

                    if (u.overflow == d) // CRUCIAL: in order not to take all the mem
                        Q.push_back(upos);
                }
            }

            if (v.overflow == 0)
                break;
        }
        if (v.overflow == 0)
            continue;
    
        if (v.height > g.sink.height && v.c[g.SINK] > 0) {
        // if (v.height == g.sink.height + 1 && v.c[g.SINK] > 0) {
            int d = std::min(v.overflow, v.c[g.SINK]);
            v.overflow          -= d;
            v.c[g.SINK]         -= d;
            g.sink.c[vpos]      += d;
            g.sink.overflow     += d;
        }
        if (v.overflow == 0)
            continue;
        if (v.height > g.source.height && v.c[g.SOURCE] > 0) {
        // if (v.height == g.source.height + 1 && v.c[g.SOURCE] > 0) {
            int d = std::min(v.overflow, v.c[g.SOURCE]);
            v.overflow          -= d;
            v.c[g.SOURCE]       -= d;
            g.source.c[vpos]    += d;
            g.source.overflow   += d;
        }
        if (v.overflow == 0)
            continue;

        /*
         * It's safe now to relabel.
         */
        bool relabel = true;
        int min_height = INF;
        for (int i = 0; i < g.REG_NEIGHBOURS; i++) {
            if (in_range(y + delt[i][0], 0, g.height - 1) &&
              in_range(x + delt[i][1], 0, g.width - 1)) {
                const int dy = y + delt[i][0];
                const int dx = x + delt[i][1];
                const int upos = dy*g.width + dx;
                regular_node_t &u = g.nodes[upos];
                
                if (v.c[i] > 0) {
                    if (v.height > u.height) {
                        relabel = false;
                        break;
                    } else {
                        min_height = std::min(min_height, u.height);
                    }
                }
            }
        }

        if (!relabel)
            continue;

        if (v.c[g.SINK] > 0 && v.height > g.sink.height)
            continue;
        else if (v.c[g.SINK] > 0)
            min_height = std::min(min_height, g.sink.height);

        if (v.c[g.SOURCE] > 0 && v.height > g.source.height)
            continue;
        else if (v.c[g.SOURCE] > 0)
            min_height = std::min(min_height, g.source.height);

        v.height = min_height + 1;
        Q.push_back(vpos);
    }
}
