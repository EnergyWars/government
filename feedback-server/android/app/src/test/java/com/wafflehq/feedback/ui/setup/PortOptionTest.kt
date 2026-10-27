package com.wafflehq.feedback.ui.setup

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PortOptionTest {

    @Test
    fun `standard option uses the default port`() {
        assertEquals(DEFAULT_PORT, resolvePort(PortOption.Standard, "123"))
        assertEquals(8787, DEFAULT_PORT)
    }

    @Test
    fun `custom option parses the entered port`() {
        assertEquals(9000, resolvePort(PortOption.Custom, " 9000 "))
        assertEquals(1, resolvePort(PortOption.Custom, "1"))
        assertEquals(65535, resolvePort(PortOption.Custom, "65535"))
    }

    @Test
    fun `custom option rejects invalid ports`() {
        assertNull(resolvePort(PortOption.Custom, ""))
        assertNull(resolvePort(PortOption.Custom, "0"))
        assertNull(resolvePort(PortOption.Custom, "65536"))
        assertNull(resolvePort(PortOption.Custom, "abc"))
    }

    @Test
    fun `port input keeps at most five digits`() {
        assertEquals("8080", sanitizePortInput("80a8-0"))
        assertEquals("12345", sanitizePortInput("1234567"))
        assertEquals("", sanitizePortInput("port"))
    }
}
