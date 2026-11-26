// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

object ContractBytes {
    fun copyOf(bytes: ByteArray): List<UByte> = OwnedBytes(bytes.copyOf())

    private class OwnedBytes(
        private val bytes: ByteArray,
    ) : AbstractList<UByte>() {
        override val size: Int get() = bytes.size

        override fun get(index: Int): UByte = bytes[index].toUByte()

        override fun toString(): String = "ContractBytes"
    }
}
