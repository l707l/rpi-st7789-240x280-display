#include <stdio.h>
#include <stdlib.h>
#include <bcm_host.h>

int main() {
    bcm_host_init();
    DISPMANX_DISPLAY_HANDLE_T display = vc_dispmanx_display_open(0);
    if (!display) {
        printf("Failed to open display\n");
        return 1;
    }
    DISPMANX_MODEINFO_T info;
    vc_dispmanx_display_get_info(display, &info);
    printf("Dispmanx info: %dx%d\n", info.width, info.height);

    uint32_t vc_image_ptr;
    DISPMANX_RESOURCE_HANDLE_T resource = vc_dispmanx_resource_create(VC_IMAGE_RGB565, info.width, info.height, &vc_image_ptr);
    int failed = vc_dispmanx_snapshot(display, resource, 0);
    if (failed) {
        printf("Snapshot failed: %d\n", failed);
        return 1;
    }

    VC_RECT_T rect;
    vc_dispmanx_rect_set(&rect, 0, 0, info.width, info.height);
    int stride = ((info.width * 2 + 31) / 32) * 32;
    void *buffer = malloc(stride * info.height);
    vc_dispmanx_resource_read_data(resource, &rect, buffer, stride);

    FILE *f = fopen("/home/q/dispmanx.raw", "wb");
    if (f) {
        fwrite(buffer, 1, stride * info.height, f);
        fclose(f);
        printf("Saved /home/q/dispmanx.raw (%d bytes)\n", stride * info.height);
    }

    vc_dispmanx_resource_delete(resource);
    vc_dispmanx_display_close(display);
    bcm_host_deinit();
    return 0;
}
