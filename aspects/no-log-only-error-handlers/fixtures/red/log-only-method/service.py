import logging


class Poller:
    def __init__(self):
        self.log = logging.getLogger("poller")

    def step(self):
        raise RuntimeError("step")

    def tick(self):
        try:
            self.step()
        except RuntimeError:
            self.log.error("tick failed")
