// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

private class BudgetExceeded : RuntimeException()

private class EventByteBudget(
    private var remaining: Int,
) : Appendable {
    override fun append(character: Char): Appendable {
        val width = utf8Width(character)
        if (width > remaining) throw BudgetExceeded()
        remaining -= width
        return this
    }

    override fun append(value: CharSequence?): Appendable {
        val characters = value ?: "null"
        return append(characters, 0, characters.length)
    }

    override fun append(
        value: CharSequence?,
        startIndex: Int,
        endIndex: Int,
    ): Appendable {
        val characters = value ?: "null"
        for (index in startIndex until endIndex) append(characters[index])
        return this
    }
}

internal fun validateEventBudget(
    event: Event,
    limit: Int,
): DeliveryError? =
    try {
        val output = WireOutput(EventByteBudget(limit))
        writeEvent(output, event)
        output.complete()
        null
    } catch (_: BudgetExceeded) {
        DeliveryError.PayloadTooLarge
    } catch (_: Exception) {
        DeliveryError.InvalidEvent
    }
