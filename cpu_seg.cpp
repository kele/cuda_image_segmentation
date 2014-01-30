#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <deque>

#include "cpu_seg.hpp"

const float LAMBDA = 1.0f;
const float EPS = 0.00001f;
const int INF = 0x1ffffffe;

inline bool in_range(int x, int a, int b) { return a <= x && x <= b; }

/* TODO: this probably should be a little more complex */
inline float compute_edge(const pixel_t &a, const pixel_t &b)
{
    float x = (float)a.r - b.r;
    float y = (float)a.g - b.g;
    float z = (float)a.b - b.b;
    return sqrt(x*x + y*y + z*z);
}

void segmentation_cpu(unsigned width, unsigned height, const pixel_t *image,
  const pixel_t *marks, pixel_t *segmented_image)
{
    typedef ImageGraph::regular_node_t regular_node_t;
    typedef ImageGraph::node_t node_t;

    ImageGraph g(width, height);
    Histogram hist(width, height, image, marks);

    /* REG_NEIGBHOURS, unfortunately, has to be 4 here */
    /* TODO: probably make it more elastic? */
    const int delt[ImageGraph::REG_NEIGHBOURS][2] = {
                {-1,  0},
      { 0, -1},           { 0, +1},
                {+1,  0}};

    /* neighbour edges */
    for (unsigned y = 0; y < height; y++) {
        for (unsigned x = 0; x < width; x++) {
            regular_node_t &v = g.get(x, y);
            for (unsigned i = 0; i < ImageGraph::REG_NEIGHBOURS; i++) {
                if (in_range(y + delt[i][0], 0, height - 1) &&
                  in_range(x + delt[i][1], 0, width - 1)) {
                    unsigned dy = y + delt[i][0];
                    unsigned dx = x + delt[i][1];
                    regular_node_t &u = g.get(dx, dy);
                    v.c[i] = compute_edge(image[y*height + x], image[dy*height + dx]);
                }
            }
        }
    }

    /* source and sink edges */
    for (unsigned y = 0; y < height; y++) {
        for (unsigned x = 0; x < width; x++) {
            regular_node_t &v = g.get(x, y);

            float k = 0;
            for (unsigned i = 0; i < ImageGraph::REG_NEIGHBOURS; i++)
                k = (k < v.c[i]) ? v.c[i] : k;
            k = k + 1;

            unsigned i = y*height + x;
            if (marks[y*height + x] == OBJECT) {
                v.c[ImageGraph::SOURCE] = g.source.c[i] = k;
                v.c[ImageGraph::SINK] = g.sink.c[i] = 0;
            } else if (marks[y*height + x] == BACKGR) {
                v.c[ImageGraph::SINK] = g.sink.c[i] = k;
                v.c[ImageGraph::SOURCE] = g.source.c[i] = 0;
            } else {
                v.c[ImageGraph::SOURCE] = LAMBDA*(-log(hist.prob_bg(image[i])));
                v.c[ImageGraph::SINK] = LAMBDA*(-log(hist.prob_obj(image[i])));
                g.source.c[i] = v.c[ImageGraph::SOURCE];
                g.sink.c[i] = v.c[ImageGraph::SINK];
            }
        }
    }

    /* initialise preflow */
    g.source.height = width*height;
    for (unsigned y = 0; y < height; y++) {
        for (unsigned x = 0; x < width; x++) {
            regular_node_t &v = g.get(x, y);
            v.overflow = g.source.c[y*height + x];
            v.c[ImageGraph::SOURCE] += g.source.c[y*height + x];
            g.source.c[y*height + x] = 0;
        }
    }

    /*
     * Push-relabel with FIFO queue.
     */
    std::deque<int> Q;
    for (unsigned i = 0; i < g.nodes.size(); i++)
        if (g.nodes[i].overflow > 0)
            Q.push_back(i);

    while (!Q.empty()) {
        const unsigned vpos = Q.front();
        regular_node_t &v = g.nodes[vpos];
        Q.pop_front();

        bool pushed = false;
        const unsigned x = vpos % height;
        const unsigned y = vpos / height;
        for (unsigned i = 0; i < ImageGraph::REG_NEIGHBOURS; i++) {
            if (in_range(y + delt[i][0], 0, height - 1) &&
              in_range(x + delt[i][1], 0, width - 1)) {
                const unsigned dy = y + delt[i][0];
                const unsigned dx = x + delt[i][1];
                const unsigned upos = dy*height + dx;
                regular_node_t &u = g.nodes[upos];

                if (v.height == u.height + 1 && v.c[i] > 0 - EPS) {
                    float d = std::min(v.overflow, v.c[i]);
                    v.overflow -= d;
                    v.c[i] -= d;
                    u.overflow += d;
                    u.c[ImageGraph::REG_NEIGHBOURS - i] += d;
                      
                    if (u.overflow > 0)
                        Q.push_back(upos);

                    pushed = true;
                }
            }

            if (v.overflow == 0)
                break;
        }

        /*
         * In these two cases, we don't care about sink or source overflow.
         */
        if (v.overflow > 0 && v.height == g.sink.height + 1 && v.c[ImageGraph::SINK] > 0) {
            float d = std::min(v.overflow, v.c[ImageGraph::SINK]);
            v.overflow -= d; v.c[ImageGraph::SINK] -= d;
            pushed = true;
        }
        if (v.overflow > 0 && v.height == g.source.height + 1 && v.c[ImageGraph::SOURCE] > 0) {
            float d = std::min(v.overflow, v.c[ImageGraph::SOURCE]);
            v.overflow -= d; v.c[ImageGraph::SOURCE] -= d;
            pushed = true;
        }

        if (v.overflow <= 0)
            continue;
        /*
         * It's safe now to relabel.
         */
        int min_height = INF;
        for (unsigned i = 0; i < ImageGraph::REG_NEIGHBOURS; i++) {
            if (in_range(y + delt[i][0], 0, height - 1) &&
              in_range(x + delt[i][1], 0, width - 1)) {
                const unsigned dy = y + delt[i][0];
                const unsigned dx = x + delt[i][1];
                const unsigned upos = dy*height + dx;
                regular_node_t &u = g.nodes[upos];

                if (v.height <= u.height && v.c[i] > 0)
                    min_height = std::min(min_height, u.height);
            }
        }

        if (min_height != INF && min_height != v.height) {
            v.height = min_height + 1;
            Q.push_back(vpos);
        }
    }

    
}
