# Building Priism
``sudo bash priism_builder.sh image.bin``

``image.bin`` MUST be a SH1MMER Legacy image on a version newer than February 2024.

# Using Priism

After flashing your image to a USB, expand the PRIISM_IMAGES partition to fill up the rest of the drive. To add shims and recovery images, mount PRIISM_IMAGES and drop them in the ``shims`` and ``recovery`` folders respectively.

# Bug reporting
Briefly describe any errors you recieve, then rerun the builder with ``sudo bash -x priism_builder.sh image.bin``. This will help me narrow down the issue.

Further instructions will be added later.

The reccommended distro for building is something arch based, preferably cachyos
