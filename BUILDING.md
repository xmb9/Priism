# Building Priism
``sudo bash priism_builder.sh image.bin``

``image.bin`` MUST be a SH1MMER Legacy image on a version newer than February 2024.

# Using Priism

After flashing your USB, boot it so that Priism can resize the images partition. For instructions on how to add recovery images, press ``i``.<br>
If the drive is empty, it will show you where to get recovery images, and how to mount the images partition on your computer.

# Bug reporting
Briefly describe any errors you recieve, then rerun the builder with ``sudo bash -x priism_builder.sh image.bin``. This will help me narrow down the issue.

Further instructions will be added later.
