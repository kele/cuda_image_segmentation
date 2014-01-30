#ifndef __CPU_SEG_H__
#define __CPU_SEG_H__

#include <cstring>

#include "cpu_utils.h"


struct node_t {
    float c[10];  // source, sink, 8 neighbours
    float f[10];  // source, sink, 8 neighbours
    float rev_c[2]; // for source and sink
    float rev_f[2]; // for source and sink
    float overflow;
    int height;
    pixel_t color;
};

class Graph {
public:
    node_t *nodes;
    unsigned width, height;

    Graph(unsigned width, unsigned height) { init(width, height); }

    Graph(unsigned width, unsigned height, const pixel_t *image)
    {
        init(width, height);
        for (unsigned i = 0; i < width*height; i++)
            memcpy(&nodes[i].color, image[i], sizeof(pixel_t));
    }

    ~Graph() { delete [] nodes; }

    inline node_t &get(unsigned x, unsigned y) { return nodes[y*height + x]; }

private:

    void init(unsigned width, unsigned height)
    {
        this->width = width;
        this->height = height;
        nodes = new node_t[width*height];
        memset(nodes, 0, width*height*sizeof(node_t));
    }
};

#define DIV 26
class Histogram {
public:
    enum { OBJ, BG };

    Histogram(unsigned width, unsigned height, const pixel_t *image, const pixel_t *marks)
    {
        memset(count, 0, 2*10*10*10*sizeof(*count));
        total_count = width*height;

        for (unsigned i = 0; i < width*height; i++) {
            if (colordiff(marks[i], OBJECT) == 0)
                count[OBJ][image[i].r/DIV][image[i].g/DIV][image[i].b/DIV];
            else if (colordiff(marks[i], BACKGR) == 0)
                count[BG][image[i].r/DIV][image[i].g/DIV][image[i].b/DIV];
        }
    }

    inline float get_probability(int lab, const pixel_t &pix) const
    {
        return (float)count[lab][pix.r/DIV][pix.g/DIV][pix.b/DIV]/total_count;
    }

private:
    unsigned count[2][10][10][10];
    unsigned total_count;

};

/* TODO: make them methods */
inline int &c_source_rev(node_t &n) { return n.rev_c[0]; }
inline int &c_sink_rev(node_t &n) { return n.rev_c[1]; }
inline int &c_source(node_t &n) { return n.c[8]; }
inline int &c_sink(node_t &n) { return n.c[9]; }
inline int &c_neigh(node_t &n, unsigned which) { return n.c[which]; }

inline int &f_source_rev(node_t &n) { return n.rev_f[0]; }
inline int &f_sink_rev(node_t &n) { return n.rev_f[1]; }
inline int &f_source(node_t &n) { return n.f[8]; }
inline int &f_sink(node_t &n) { return n.f[9]; }
inline int &f_neigh(node_t &n, unsigned which) { return n.f[which]; }

void segmentation_cpu(unsigned width, unsigned height, const pixel_t *image,
  const pixel_t *marks, pixel_t *segmented_image);

#endif
