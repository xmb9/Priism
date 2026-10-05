# Priism
Portable recovery image installer/shim manager. Now in C++!

# What works? What doesn't?
Recovery :white_check_mark:<br>
Payloads menu :white_check_mark:<br>
Booting other shims :white_check_mark:<br>

# Downloads
Soon?

[//]: # (Mirrors that are crossed out don't have Priism uploaded yet.)
[//]: # (Mirrors with an asterisk next to them may not have all boards uploaded yet.)

# FAQ (Frequently Asked Questions)
<details>
  <summary><b>How do I update without reflashing?</b></summary>

  This requires a device to build on.
  
  1: Copy a SH1MMER legacy (Feb 2024+) image to where you downloaded the repo

  2: Run this command: ``sudo bash update_device.sh path/to/priism.bin /dev/XXX``, where ``/dev/XXX`` is your USB/sd card. You can find this with ``lsblk``.
</details>

<details>
  <summary><b>I wanna use Shimboot. How can I?</b></summary>

  You don't need to use any forks, Shimboot should function as intended.
</details>
<details>
  <summary><b>Does Priism work on Chomp?</b></summary>

  Priism 2.0 was developed entirely on Chomp!
</details>
<details>
  <summary><b>Why was Priism rewritten in C++?</b></summary>

  When Priism was written in Bash, the codebase was a mess and hard to maintain, and had generally odd quirks and bugs.<br>
  The C++ rewrite should be far more performant, stable, and easier to maintain.
</details>

# Credits
- [xmb9](https://discord.com/users/988950574387068968) - Pioneering the creation of this tool
- [Mercury Workshop](https://mercurywork.shop) - Developing SH1MMER, which this tool needs for building
- [OlyB](https://discord.com/users/476169716998733834) - Help with adapting wax to Priism and PID1
- [kxtzownsu](https://discord.com/users/952792525637312552) - Help with `sed` syntax
- [Simon](https://discord.com/users/1001820177731686500) - Testing Priism and building the very first shims