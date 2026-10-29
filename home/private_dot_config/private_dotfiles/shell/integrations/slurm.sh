# These command preferences do not imply that this device is a Linux cluster.
export SQUEUE_FORMAT="${SQUEUE_FORMAT:-%.12i %.9P %.20j %.12u %.4Q %.2T %.10M %.9l %.6D %R}"
alias jobinfo='scontrol show jobid -dd'
