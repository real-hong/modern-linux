-- -l makes assertion failures exit nonzero; +lua followed by +q can hide errors.
vim.cmd.edit('/tmp/input')
assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == 'alpha')
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'saved by nvim' })
vim.cmd.write('/tmp/nvim-output')
assert(vim.fn.readfile('/tmp/nvim-output')[1] == 'saved by nvim')

local child = vim.fn.jobstart({ '/bin/sh', '-c', 'exit 0' })
assert(child > 0, 'failed to spawn child')
assert(vim.fn.jobwait({ child }, 5000)[1] == 0, 'child did not exit successfully')

local pty = vim.fn.jobstart({ '/bin/sh', '-c', 'exit 7' }, { pty = true })
assert(pty > 0, 'failed to allocate PTY')
assert(vim.fn.jobwait({ pty }, 5000)[1] == 7, 'PTY child exit status was lost')
